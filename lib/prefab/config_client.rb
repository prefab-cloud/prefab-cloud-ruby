module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @config_loader = Prefab::ConfigLoader.new(base_client)
      @config_resolver = Prefab::ConfigResolver.new(base_client, @config_loader)
      boot_resolver
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def set(key, config_value, namespace = nil)
      raise "key must not contain ':' set namespaces separately" if key.include? ":"
      config_delta = self.value_to_delta(key, config_value, namespace)
      Retry.it method(:stub_with_timout), :upsert, config_delta, @timeout
      @config_resolver.set(config_delta)
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

    def boot_resolver
      start_at_id = 0

      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: start_at_id)

      Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_resolver.set(delta, do_update: false)
              end
              @config_resolver.update


              puts "save #{@config_resolver.export_api_deltas}"
              @base_client.write(cache_key, @config_resolver.export_api_deltas.encode)

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

