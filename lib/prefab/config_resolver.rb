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
          case value.type
          when :string then
            str << "#{k} #{value.string}"
          when :int then
            str << "#{k} #{value.int}"
          end
        end
      end
      str
    end

    def get(property)
      value = @lock.with_read_lock do
        @local_store[property][:value]
      end
      case value.type
      when :string then
        value.string
      when :int then
        value.int
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
      end
      @lock.with_write_lock do
        @local_store = store
      end

      @logger.info "Updated to #{to_s}"
    end
  end
end
