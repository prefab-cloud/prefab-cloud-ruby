module Prefab
  class ConfigClient
    include Prefab::ConfigHelper

    RECONNECT_WAIT = 5
    DEFAULT_CHECKPOINT_FREQ_SEC = 60
    DEFAULT_S3CF_BUCKET = 'http://d2j4ed6ti5snnd.cloudfront.net'


    def initialize(base_client, timeout)
      @base_client = base_client
      @base_client.log_internal Logger::DEBUG, "Initialize ConfigClient"
      @timeout = timeout

      @stream_lock = Concurrent::ReadWriteLock.new

      @checkpoint_freq_secs = DEFAULT_CHECKPOINT_FREQ_SEC

      @config_loader = Prefab::ConfigLoader.new(@base_client)
      @config_resolver = Prefab::ConfigResolver.new(@base_client, @config_loader)

      @initialization_lock = Concurrent::ReadWriteLock.new
      @base_client.log_internal Logger::DEBUG, "Initialize ConfigClient: AcquireWriteLock"
      @initialization_lock.acquire_write_lock
      @base_client.log_internal Logger::DEBUG, "Initialize ConfigClient: AcquiredWriteLock"
      @initialized_future = Concurrent::Future.execute { @initialization_lock.acquire_read_lock }

      @cancellable_interceptor = Prefab::CancellableInterceptor.new(@base_client)

      @s3_cloud_front = ENV["PREFAB_S3CF_BUCKET"] || DEFAULT_S3CF_BUCKET

      if @base_client.options.local_only
        finish_init!(:local_only)
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

    def upsert(key, config_value, namespace = nil, previous_key = nil)
      raise "Key must not contain ':' set namespaces separately" if key.include? ":"
      raise "Namespace must not contain ':'" if namespace&.include?(":")
      config_delta = Prefab::ConfigClient.value_to_delta(key, config_value, namespace)
      upsert_req = Prefab::UpsertRequest.new(config_delta: config_delta)
      upsert_req.previous_key = previous_key if previous_key&.present?

      @base_client.request Prefab::ConfigService, :upsert, req_options: { timeout: @timeout }, params: upsert_req
      @base_client.stats.increment("prefab.config.upsert")
      @config_loader.set(config_delta)
      @config_loader.rm(previous_key) if previous_key&.present?
      @config_resolver.update
    end

    def reset
      @base_client.reset!
      @_stub = nil
    end

    def to_s
      @config_resolver.to_s
    end

    def self.value_to_delta(key, config_value, namespace = nil)
      Prefab::Config.new(key: [namespace, key].compact.join(":"),
                         rows: [Prefab::ConfigRow.new(value: config_value)])
    end

    def get(key)
      config = _get(key)
      config ? value_of(config[:value]) : nil
    end

    def get_config_obj(key)
      config = _get(key)
      config ? config[:config] : nil
    end

    private

    def _get(key)
      # wait timeout sec for the initalization to be complete
      @initialized_future.value(@base_client.options.initialization_timeout_sec)
      if @initialized_future.incomplete?
        if @base_client.options.on_init_failure == Prefab::Options::ON_INITIALIZATION_FAILURE::RETURN
          @base_client.log_internal Logger::WARN, "Couldn't Initialize In #{@base_client.options.initialization_timeout_sec}. Key #{key}. Returning what we have"
          @initialization_lock.release_write_lock
        else
          raise "Prefab Couldn't Initialize In #{@base_client.options.initialization_timeout_sec} 2 timeout. Key #{key}. "
        end
      end
      @config_resolver._get(key)
    end

    def stub
      @_stub = Prefab::ConfigService::Stub.new(nil,
                                               nil,
                                               channel_override: @base_client.channel,
                                               interceptors: [@base_client.interceptor, @cancellable_interceptor])
    end

    # try API first, if not, fallback to s3
    def load_checkpoint
      success = load_checkpoint_from_grpc_api

      if !success
        @base_client.log_internal Logger::INFO, "Fallback to S3"
        load_checkpoint_from_s3
      end
    rescue => e
      @base_client.log_internal Logger::WARN, "Unexpected problem loading checkpoint #{e}"
    end

    def load_checkpoint_from_grpc_api
      config_req = Prefab::ConfigServicePointer.new(start_at_id: @config_loader.highwater_mark)

      resp = stub.get_all_config(config_req)
      load_configs(resp, :grpc)
      true
    rescue GRPC::Unauthenticated
      @base_client.log_internal Logger::WARN, "Unauthenticated"
    rescue => e
      puts e.class
      @base_client.log_internal Logger::WARN, "Unexpected problem loading checkpoint #{e}"
      false
    end

    def load_checkpoint_from_s3
      url = "#{@s3_cloud_front}/#{@base_client.api_key.gsub("|", "/")}"
      resp = Faraday.get url
      if resp.status == 200
        configs = Prefab::Configs.decode(resp.body)
        load_configs(configs, :s3)
      else
        @base_client.log_internal Logger::INFO, "No S3 checkpoint. Response #{resp.status}"
      end
    end

    def load_configs(configs, source)
      project_env_id = configs.config_service_pointer.project_env_id
      @config_resolver.project_env_id = project_env_id
      starting_highwater_mark = @config_loader.highwater_mark

      configs.configs.each do |config|
        @config_loader.set(config, source)
      end
      if @config_loader.highwater_mark > starting_highwater_mark
        @base_client.log_internal Logger::INFO, "Found new checkpoint with highwater id #{@config_loader.highwater_mark} from #{source} in project #{@base_client.project_id} environment: #{project_env_id} and namespace: '#{@namespace}'"
      else
        @base_client.log_internal Logger::DEBUG, "Checkpoint with highwater id #{@config_loader.highwater_mark} from #{source}. No changes."
      end
      @base_client.stats.increment("prefab.config.checkpoint.load")
      @config_resolver.update
      finish_init!(source)
    end

    # A thread that checks for a checkpoint
    def start_checkpointing_thread

      Thread.new do
        loop do
          begin
            load_checkpoint

            started_at = Time.now
            delta = @checkpoint_freq_secs - (Time.now - started_at)
            if delta > 0
              sleep(delta)
            end
          rescue StandardError => exn
            @base_client.log_internal Logger::INFO, "Issue Checkpointing #{exn.message}"
          end
        end
      end
    end

    def finish_init!(source)
      if @initialization_lock.write_locked?
        @base_client.log_internal Logger::INFO, "Unlocked Config via #{source}"
        @initialization_lock.release_write_lock
        @base_client.log.set_config_client(self)
      end
    end

    def start_sse_streaming_connection_thread(start_at_id)
      auth = "#{@base_client.project_id}:#{@base_client.api_key}"
      auth_string = Base64.strict_encode64(auth)
      headers = {
        "x-prefab-start-at-id": start_at_id,
        "Authorization": "Basic #{auth_string}",
      }
      url = "#{@base_client.prefab_api_url}/api/v1/sse/config"
      @base_client.log_internal Logger::INFO, "SSE Streaming Connect to #{url}"
      @streaming_thread = SSE::Client.new(url, headers: headers) do |client|
        client.on_event do |event|
          configs = Prefab::Configs.decode(Base64.decode64(event.data))
          load_configs(configs, :sse)
        end
      end
    end
  end
end

