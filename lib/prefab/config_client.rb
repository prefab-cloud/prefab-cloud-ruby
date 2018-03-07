module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5
    CHECKPOINT_FREQ_SEC = 10
    SUSPENDERS_FREQ_SEC = 60

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @config_loader = Prefab::ConfigLoader.new(@base_client)
      @config_resolver = Prefab::ConfigResolver.new(@base_client, @config_loader)
      start_at_id = load_checkpoint
      start_api_connection_thread(start_at_id)
      start_checkpointing_thread
      start_suspenders_thread
      @base_client.log.set_config_client(self)
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def upsert(key, config_value, namespace = nil, previous_key = nil)
      raise "key must not contain ':' set namespaces separately" if key.include? ":"
      raise "namespace must not contain ':'" if namespace&.include?(":")
      config_delta = Prefab::ConfigClient.value_to_delta(key, config_value, namespace)
      upsert_req = Prefab::UpsertRequest.new(config_delta: config_delta)
      upsert_req.previous_key = previous_key if previous_key&.present?

      @base_client.request Prefab::ConfigService, :upsert, req_options: { timeout: @timeout }, params: upsert_req

      @config_loader.set(config_delta)
      @config_loader.rm(previous_key) if previous_key&.present?
      @config_resolver.update
    end

    def reset
      @base_client.reset_channel!
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
          @config_loader.set(delta)
          start_at_id = [delta.id, start_at_id].max
        end
        @base_client.log_internal :info, "Found checkpoint with highwater id #{start_at_id}"
        @config_resolver.update
      else
        @base_client.log_internal :info, "No checkpoint"
      end

      start_at_id
    end

    # A thread that saves current state to the cache, "checkpointing" it
    def start_checkpointing_thread
      Thread.new do
        loop do
          begin
            started_at = Time.now
            delta = CHECKPOINT_FREQ_SEC - (Time.now - started_at)
            if delta > 0
              sleep(delta)
            end
            deltas = @config_resolver.export_api_deltas
            @base_client.log_internal :debug, "Save Checkpoint #{deltas.deltas.map {|d| d.id}.max} Thread #{Thread.current.object_id}"
            @base_client.shared_cache.write(cache_key, Prefab::ConfigDeltas.encode(deltas))
          rescue StandardError => exn
            @base_client.log_internal :info, "Issue Checkpointing #{exn.message}"
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
            @base_client.log_internal :info, ("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
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

            resp = @base_client.request Prefab::ConfigService, :get_config, req_options: { timeout: @timeout }, params: config_req

            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
                start_at_suspenders = [start_at_suspenders, delta.id].max
              end
            end
          rescue GRPC::DeadlineExceeded
            # Ignore. This is a streaming endpoint, but we only need a single response
          rescue => e
            @base_client.log_internal :info, "Suspenders encountered an issue #{e.message}"
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

