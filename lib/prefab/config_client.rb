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
      Retry.it method(:stub_with_timout), :upsert, config_delta, @timeout
      @config_loader.set(config_delta)
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
      Prefab::ConfigService::Stub.new(nil,
                                      nil,
                                      channel_override: @base_client.channel,
                                      interceptors: [@base_client.interceptor])
    end

    def stub_with_timout
      Prefab::ConfigService::Stub.new(nil,
                                      nil,
                                      channel_override: @base_client.channel,
                                      timeout: @timeout,
                                      interceptors: [@base_client.interceptor])
    end

    def cache_key
      "prefab:config:checkpoint"
    end

    def load_checkpoint
      checkpoint = @base_client.shared_cache.read(cache_key)
      start_at_id = 0

      if checkpoint
        deltas = Prefab::ConfigDeltas.decode(checkpoint)
        deltas.deltas.each do |delta|
          # puts "checkpoint set #{delta.key} #{delta.value.int} #{delta.value.string} #{delta.id} "
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

    def start_checkpointing_thread
      Thread.new do
        loop do
          begin
            started_at = Time.now
            deltas = @config_resolver.export_api_deltas
            puts "==SAVE TO CACHE===VVV====#{deltas.deltas.map {|d| d.id}.max}====="
            @base_client.shared_cache.write(cache_key, Prefab::ConfigDeltas.encode(deltas))
            delta = CHECKPOINT_FREQ_SEC - (Time.now - started_at)
            if delta > 0
              sleep(delta)
            end
          rescue StandardError => exn
            puts exn
          end
        end
      end
    end

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
            sleep(RECONNECT_WAIT)
            @base_client.logger.info("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
          end
        end
      end
    end

    def start_suspenders_thread
      start_at_suspenders = 0

      Thread.new do
        loop do
          begin
            started_at = Time.now
            @base_client.logger.info "SUSPENDERS #{start_at_suspenders}"
            config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                          start_at_id: start_at_suspenders)
            resp = stub_with_timout.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
                start_at_suspenders = [start_at_suspenders, delta.id].max
              end
            end
          rescue GRPC::DeadlineExceeded
          end

          delta = CHECKPOINT_FREQ_SEC - (Time.now - started_at)
          if delta > 0
            sleep(delta)
          end
        end
      end
    end
  end
end

