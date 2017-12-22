module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5

    def initialize(client, timeout)
      @client = client
      @timeout = timeout
      @config_resolver = EzConfig::ConfigResolver.new(client)
      boot_resolver
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def set(config_delta)
      Retry.it method(:stub_with_timout), :upsert, config_delta, @timeout
    end

    def to_s
      @config_resolver.to_s
    end

    private

    def stub
      Prefab::ConfigService::Stub.new(nil,
                                      nil,
                                      channel_override: @client.channel,
                                      interceptors: [@client.interceptor])
    end

    def stub_with_timout
      Prefab::ConfigService::Stub.new(nil,
                                      nil,
                                      channel_override: @client.channel,
                                      timeout: @timeout,
                                      interceptors: [@client.interceptor])
    end

    def boot_resolver
      config_req = Prefab::ConfigServicePointer.new(account_id: @client.account_id,
                                                    start_at_id: 0)

      Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_resolver.set(delta)
              end
              @config_resolver.update
            end
          rescue => e
            sleep(RECONNECT_WAIT)
            @client.logger.info("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
          end
        end
      end
    end
  end
end

