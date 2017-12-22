module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @config_resolver = EzConfig::ConfigResolver.new(base_client)
      boot_resolver
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def set(config_delta)
      Retry.it method(:stub_with_timout), :upsert, config_delta, @timeout
      @config_resolver.set(config_delta)
    end

    def to_s
      @config_resolver.to_s
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

    def boot_resolver
      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: 0)

      Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_resolver.set(delta, do_update: false)
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
  end
end

