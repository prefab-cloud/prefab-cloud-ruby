module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5
    DEFAULT_CHECKPOINT_FREQ_SEC = 60
    DEFAULT_S3CF_BUCKET = 'http://d2j4ed6ti5snnd.cloudfront.net'

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @initialization_lock = Concurrent::ReadWriteLock.new

      @checkpoint_freq_secs = DEFAULT_CHECKPOINT_FREQ_SEC

      @config_loader = Prefab::ConfigLoader.new(@base_client)
      @config_resolver = Prefab::ConfigResolver.new(@base_client, @config_loader)

      @initialization_lock.acquire_write_lock

      @s3_cloud_front = ENV["PREFAB_S3CF_BUCKET"] || DEFAULT_S3CF_BUCKET
      load_checkpoint
      start_checkpointing_thread
    end

    def start_streaming
      start_api_connection_thread(@config_loader.highwater_mark)
    end

    def get(prop)
      @initialization_lock.with_read_lock do
        @config_resolver.get(prop)
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
      Prefab::ConfigDelta.new(key: [namespace, key].compact.join(":"),
                              value: config_value)
    end

    private

    def stub
      @_stub = Prefab::ConfigService::Stub.new(nil,
                                               nil,
                                               channel_override: @base_client.channel,
                                               interceptors: [@base_client.interceptor])
    end

    # Bootstrap out of the cache
    # returns the high-watermark of what was in the cache
    def load_checkpoint
      success = load_checkpoint_from_config

      if !success
        @base_client.log_internal Logger::INFO, "Fallback to S3"
        load_checkpoint_from_s3
      end

    rescue => e
      @base_client.log_internal Logger::WARN, "Unexpected problem loading checkpoint #{e}"
    end

    def load_checkpoint_from_config
      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: @config_loader.highwater_mark)
      resp = stub.get_all_config(config_req)
      load_deltas(resp, :api)
      resp.deltas.each do |delta|
        @config_loader.set(delta)
      end
      @config_resolver.update
      finish_init!(:api)
      true
    rescue => e
      @base_client.log_internal Logger::WARN, "Unexpected problem loading checkpoint #{e}"
      false
    end

    def load_checkpoint_from_s3
      url = "#{@s3_cloud_front}/#{@base_client.api_key.gsub("|", "/")}"
      resp = Faraday.get url
      if resp.status == 200
        deltas = Prefab::ConfigDeltas.decode(resp.body)
        load_deltas(deltas, :s3)
      else
        @base_client.log_internal Logger::INFO, "No S3 checkpoint. Response #{resp.status} Plan may not support this."
      end
    end


    def load_deltas(deltas, source)
      deltas.deltas.each do |delta|
        @config_loader.set(delta)
      end
      @base_client.log_internal Logger::INFO, "Found checkpoint with highwater id #{@config_loader.highwater_mark} from #{source}"
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
        @base_client.log_internal Logger::DEBUG, "Unlocked Config via #{source}"
        @initialization_lock.release_write_lock
        @base_client.log.set_config_client(self)
      end
    end

    # Setup a streaming connection to the API
    # Save new config values into the loader
    def start_api_connection_thread(start_at_id)
      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: start_at_id)
      @base_client.log_internal Logger::DEBUG, "start api connection thread #{start_at_id}"
      @base_client.stats.increment("prefab.config.api.start")
      @api_connection_thread = Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
              end
              @config_resolver.update
              finish_init!(:streaming)
            end
          rescue => e
            @base_client.log_internal Logger::INFO, ("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
            reset
            sleep(RECONNECT_WAIT)
          end
        end
      end
    end
  end
end

