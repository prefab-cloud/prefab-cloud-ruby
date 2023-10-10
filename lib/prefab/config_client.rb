# frozen_string_literal: true

module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5
    DEFAULT_CHECKPOINT_FREQ_SEC = 60
    SSE_READ_TIMEOUT = 300
    AUTH_USER = 'authuser'
    LOGGING_KEY_PREFIX = "#{Prefab::LoggerClient::BASE_KEY}#{Prefab::LoggerClient::SEP}".freeze

    def initialize(base_client, timeout)
      @base_client = base_client
      @options = base_client.options
      @base_client.log_internal ::Logger::DEBUG, 'Initialize ConfigClient'
      @timeout = timeout

      @stream_lock = Concurrent::ReadWriteLock.new

      @checkpoint_freq_secs = DEFAULT_CHECKPOINT_FREQ_SEC

      @config_loader = Prefab::ConfigLoader.new(@base_client)
      @config_resolver = Prefab::ConfigResolver.new(@base_client, @config_loader)

      @initialization_lock = Concurrent::ReadWriteLock.new
      @base_client.log_internal ::Logger::DEBUG, 'Initialize ConfigClient: AcquireWriteLock'
      @initialization_lock.acquire_write_lock
      @base_client.log_internal ::Logger::DEBUG, 'Initialize ConfigClient: AcquiredWriteLock'
      @initialized_future = Concurrent::Future.execute { @initialization_lock.acquire_read_lock }

      if @options.local_only?
        finish_init!(:local_only, nil)
      else
        load_checkpoint
        start_checkpointing_thread
        start_streaming
      end
    end

    def start_streaming
      @stream_lock.with_write_lock do
        start_sse_streaming_connection_thread(@config_loader.highwater_mark) if @streaming_thread.nil?
      end
    end

    def to_s
      @config_resolver.to_s
    end

    def resolver
      @config_resolver
    end

    def self.value_to_delta(key, config_value, namespace = nil)
      PrefabProto::Config.new(key: [namespace, key].compact.join(':'),
                              rows: [PrefabProto::ConfigRow.new(value: config_value)])
    end

    def get(key, default = NO_DEFAULT_PROVIDED, properties = NO_DEFAULT_PROVIDED)
      context = @config_resolver.make_context(properties)

      if !context.blank? && @base_client.example_contexts_aggregator
        @base_client.example_contexts_aggregator.record(context)
      end

      evaluation = _get(key, context)

      @base_client.context_shape_aggregator&.push(context)

      if evaluation
        evaluation.report_and_return(@base_client.evaluation_summary_aggregator)
      else
        handle_default(key, default)
      end
    end

    private

    def raw(key)
      @config_resolver.raw(key)
    end

    def handle_default(key, default)
      return default if default != NO_DEFAULT_PROVIDED

      raise Prefab::Errors::MissingDefaultError, key if @options.on_no_default == Prefab::Options::ON_NO_DEFAULT::RAISE

      nil
    end

    def _get(key, properties)
      # wait timeout sec for the initialization to be complete
      @initialized_future.value(@options.initialization_timeout_sec)
      if @initialized_future.incomplete?
        unless @options.on_init_failure == Prefab::Options::ON_INITIALIZATION_FAILURE::RETURN
          raise Prefab::Errors::InitializationTimeoutError.new(@options.initialization_timeout_sec, key)
        end

        @base_client.log_internal ::Logger::WARN,
                                  "Couldn't Initialize In #{@options.initialization_timeout_sec}. Key #{key}. Returning what we have"
        @initialization_lock.release_write_lock
      end

      @config_resolver.get key, properties
    end

    def load_checkpoint
      success = load_checkpoint_api_cdn

      return if success

      success = load_checkpoint_api

      return if success

      success = load_cache

      return if success

      @base_client.log_internal ::Logger::WARN, 'No success loading checkpoints'
    end

    def load_checkpoint_api_cdn
      conn = Prefab::HttpConnection.new("#{@options.url_for_api_cdn}/api/v1/configs/0", @base_client.api_key)
      load_url(conn, :remote_cdn_api)
    end

    def load_checkpoint_api
      conn = Prefab::HttpConnection.new("#{@options.prefab_api_url}/api/v1/configs/0", @base_client.api_key)
      load_url(conn, :remote_api)
    end

    def load_url(conn, source)
      resp = conn.get('')
      if resp.status == 200
        configs = PrefabProto::Configs.decode(resp.body)
        load_configs(configs, source)
        cache_configs(configs)
        true
      else
        @base_client.log_internal ::Logger::INFO, "Checkpoint #{source} failed to load. Response #{resp.status}"
        false
      end
    rescue StandardError => e
      @base_client.log_internal ::Logger::WARN, "Unexpected #{source} problem loading checkpoint #{e} #{conn}"
      false
    end

    def load_configs(configs, source)
      project_id = configs.config_service_pointer.project_id
      project_env_id = configs.config_service_pointer.project_env_id
      @config_resolver.project_env_id = project_env_id
      starting_highwater_mark = @config_loader.highwater_mark

      default_contexts = configs.default_context&.contexts&.map do |context|
        [
          context.type,
          context.values.keys.map do |k|
            [k, Prefab::ConfigValueUnwrapper.new(context.values[k]).unwrap]
          end.to_h
        ]
      end.to_h

      @config_resolver.default_context = default_contexts || {}

      configs.configs.each do |config|
        @config_loader.set(config, source)
      end
      if @config_loader.highwater_mark > starting_highwater_mark
        @base_client.log_internal ::Logger::DEBUG,
                                  "Found new checkpoint with highwater id #{@config_loader.highwater_mark} from #{source} in project #{project_id} environment: #{project_env_id} and namespace: '#{@namespace}'"
      else
        @base_client.log_internal ::Logger::DEBUG,
                                  "Checkpoint with highwater id #{@config_loader.highwater_mark} from #{source}. No changes.", 'load_configs'
      end
      @config_resolver.update
      finish_init!(source, project_id)
    end

    def cache_path
      return @cache_path unless @cache_path.nil?

      @cache_path ||= File.join(ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')), "prefab.cache.#{@base_client.options.api_key_id}.json")
      FileUtils.mkdir_p(File.dirname(@cache_path))
      @cache_path
    end

    def cache_configs(configs)
      return unless @options.use_local_cache && !@options.is_fork
      File.open(cache_path, "w") do |f|
        f.flock(File::LOCK_EX)
        f.write(PrefabProto::Configs.encode_json(configs))
      end
      @base_client.log_internal ::Logger::DEBUG, "Cached configs to #{cache_path}"
    rescue
      @base_client.log_internal ::Logger::DEBUG, "Failed to cache configs to #{cache_path}"
    end

    def load_cache
      return false unless @options.use_local_cache
      File.open(cache_path) do |f|
        configs = PrefabProto::Configs.decode_json(f.read)
        load_configs(configs, :cache)
      end
    rescue
      @base_client.log_internal ::Logger::DEBUG, "Failed to read cached configs at #{cache_path}"
      false
    end

    # A thread that checks for a checkpoint
    def start_checkpointing_thread
      Thread.new do
        loop do
          load_checkpoint

          started_at = Time.now
          delta = @checkpoint_freq_secs - (Time.now - started_at)
          sleep(delta) if delta > 0
        rescue StandardError => e
          @base_client.log_internal ::Logger::DEBUG, "Issue Checkpointing #{e.message}"
        end
      end
    end

    def finish_init!(source, project_id)
      return unless @initialization_lock.write_locked?

      @base_client.log_internal ::Logger::DEBUG, "Unlocked Config via #{source}"
      @initialization_lock.release_write_lock
      @base_client.log.config_client = self
      presenter = Prefab::ConfigClientPresenter.new(
        size: @config_resolver.local_store.size,
        source: source,
        project_id: project_id,
        project_env_id: @config_resolver.project_env_id,
        api_key_id: @base_client.options.api_key_id
      )
      @base_client.log_internal ::Logger::INFO, presenter.to_s
      @base_client.log_internal ::Logger::DEBUG, to_s
    end

    def start_sse_streaming_connection_thread(start_at_id)
      auth = "#{AUTH_USER}:#{@base_client.api_key}"
      auth_string = Base64.strict_encode64(auth)
      headers = {
        'x-prefab-start-at-id' => start_at_id,
        'Authorization' => "Basic #{auth_string}",
        'X-PrefabCloud-Client-Version' => "prefab-cloud-ruby-#{Prefab::VERSION}"
      }
      url = "#{@base_client.prefab_api_url}/api/v1/sse/config"
      @base_client.log_internal ::Logger::DEBUG, "SSE Streaming Connect to #{url} start_at #{start_at_id}"
      @streaming_thread = SSE::Client.new(url,
                                          headers: headers,
                                          read_timeout: SSE_READ_TIMEOUT,
                                          logger: Prefab::SseLogger.new(@base_client.log)) do |client|
        client.on_event do |event|
          configs = PrefabProto::Configs.decode(Base64.decode64(event.data))
          load_configs(configs, :sse)
        end
      end
    end
  end
end
