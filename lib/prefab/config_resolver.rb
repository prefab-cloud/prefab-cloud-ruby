module EzConfig
  class ConfigResolver

    def initialize(namespace)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @namespace = namespace
      @config_loader = EzConfig::ConfigLoader.new
      make_local
    end

    def get(property)
      @lock.with_read_lock do
        @local_store[property][:value]
      end
    end

    def set(delta)
      @config_loader.set(delta)
    end

    def update
      make_local
    end

    private

    def make_local
      store = {}
      @config_loader.calc_config.each do |prop, value|
        property = prop
        namespace = ""
        split = prop.split(":")

        if split.size > 1
          property = split[1..-1].join
          namespace = split[0]
        end

        if (namespace == "") || namespace.start_with?(@namespace)
          existing = store[property]
          if existing.nil?
            store[property] = { namespace: namespace, value: value }
          elsif existing[:namespace].split(".").size < namespace.split(".").size
            store[property] = { namespace: namespace, value: value }
          end
        end

        puts "prop #{property} namespace #{namespace} value #{value}"
      end
      @lock.with_write_lock do
        @local_store = store
      end
    end
  end
end
