module Prefab
  class ConfigClient
    def initialize(config_service, client)
      @client = client
      @config_service = config_service
      @config_resolver = EzConfig::ConfigResolver.new(client)
      boot_resolver(@config_service)
    end

    def get(prop)
      @config_resolver.get(prop)
    end

    def set(config_value)
      @config_service.upsert(config_value)
    end

    private

    def boot_resolver(config_service)
      config_req = Prefab::ConfigServicePointer.new(account_id: 1,
                                                    start_at_id: 0)

      Thread.new do
        begin
          resp = config_service.get_config(config_req)
          resp.each do |r|
            r.deltas.each do |delta|
              @config_resolver.set(delta)
            end
            @config_resolver.update
          end
        rescue => e
          @client.logger.warn(e)
        end
      end
    end
  end
end

