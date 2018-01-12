module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5
    CHECKPOINT_FREQ_SEC = 10
    SUSPENDERS_FREQ_SEC = 60

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @config_loader = Prefab::ConfigLoader.new(base_client)
      @config_resolver = Prefab::ConfigResolver.new(base_client, @config_loader)
      start_at_id = load_checkpoint
      start_api_connection_thread(start_at_id)
      start_checkpointing_thread
      start_suspenders_thread
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def set(key, config_value, namespace = nil)
      raise "key must not contain ':' set namespaces separately" if key.include? ":"
      raise "namespace must not contain ':'" if namespace&.include?(":")
      config_delta = Prefab::ConfigClient.value_to_delta(key, config_value, namespace)
      Retry.it method(:stub_with_timeout), :upsert, config_delta, @timeout, method(:reset)
      @config_loader.set(config_delta)
    end

    def reset
      @base_client.reset_channel!
      @_stub = nil
      @_stub_with_timeout = nil
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

    def stub_with_timeout
      @_stub_with_timeout = Prefab::ConfigService::Stub.new(nil,
                                                            nil,
                                                            channel_override: @base_client.channel,
                                                            timeout: @timeout,
                                                            interceptors: [@base_client.interceptor])
    end

    def cache_key
      "prefab:config:checkpoint"
    end

    # Bootstrap out of the cache
    # returns the high-watermark of what was in the cache
    def load_checkpoint
      checkpoint = @base_client.shared_cache.read(cache_key)
      start_at_id = 0

      if checkpoint
        deltas = Prefab::ConfigDeltas.decode(checkpoint)
        deltas.deltas.each do |delta|
          @base_client.logger.debug "checkpoint set #{delta.key} #{delta.value.int} #{delta.value.string} #{delta.id} "
          @config_loader.set(delta)
          start_at_id = [delta.id, start_at_id].max
        end
        @base_client.logger.info "Found checkpoint with highwater id #{start_at_id}"
        @config_resolver.update
      else
        @base_client.logger.info "No checkpoint"
      end

      start_at_id
    end

    # A thread that saves current state to the cache, "checkpointing" it
    def start_checkpointing_thread
      Thread.new do
        loop do
          begin
            started_at = Time.now
            deltas = @config_resolver.export_api_deltas
            @base_client.logger.debug "==CHECKPOINT==#{deltas.deltas.map {|d| d.id}.max}====="
            @base_client.shared_cache.write(cache_key, Prefab::ConfigDeltas.encode(deltas))
            delta = CHECKPOINT_FREQ_SEC - (Time.now - started_at)
            if delta > 0
              sleep(delta)
            end
          rescue StandardError => exn
            @base_client.logger.info "Issue Checkpointing #{exn.message}"
          end
        end
      end
    end

    # Setup a streaming connection to the API
    # Save new config values into the loader
    def start_api_connection_thread(start_at_id)
      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: start_at_id)
      Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
              end
              @config_resolver.update
            end
          rescue => e
            @base_client.logger.info("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
            reset
            sleep(RECONNECT_WAIT)
          end
        end
      end
    end

    # Streaming connections don't guarantee all items have been seen
    #
    def start_suspenders_thread
      start_at_suspenders = 0

      Thread.new do
        loop do
          begin
            started_at = Time.now
            config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                          start_at_id: start_at_suspenders)
            resp = stub_with_timeout.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
                start_at_suspenders = [start_at_suspenders, delta.id].max
              end
            end
          rescue GRPC::DeadlineExceeded
            # Ignore. This is a streaming endpoint, but we only need a single response
          rescue => e
            @base_client.logger.info "Suspenders encountered an issue #{e.message}"
          end

          delta = SUSPENDERS_FREQ_SEC - (Time.now - started_at)
          if delta > 0
            sleep(delta)
          end
        end
      end
    end
  end
end

