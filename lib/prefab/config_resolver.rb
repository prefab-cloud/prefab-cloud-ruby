module EzConfig
  class ConfigResolver

    def initialize(client)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @namespace = client.namespace
      @config_loader = EzConfig::ConfigLoader.new(client.logger)
      @logger = client.logger
      make_local
    end

    def to_s
      str = ""
      @lock.with_read_lock do
        @local_store.each do |k, v|
          value = v[:value]
          str << "|#{k}| |#{value_of(value)}|#{value_of(value).class}\n"
        end
      end
      str
    end

    def get(property)
      config = @lock.with_read_lock do
        @local_store[property]
      end
      config ? value_of(config[:value]) : nil
    end

    def set(delta, do_update: true)
      @config_loader.set(delta)
      update if do_update
    end

    def update
      make_local
    end

    private

    def value_of(config_value)
      case config_value.type
      when :string
        config_value.string
      when :int
        config_value.int
      when :double
        config_value.double
      when :bool
        config_value.bool
      when :feature_flag
        config_value.feature_flag
      end
    end

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
      end
      @lock.with_write_lock do
        @local_store = store
      end
    end
  end
end
