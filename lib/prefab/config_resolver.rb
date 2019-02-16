module Prefab
  class ConfigResolver
    NAMESPACE_DELIMITER = ".".freeze
    NAME_KEY_DELIMITER = ":".freeze

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @namespace = base_client.namespace
      @config_loader = config_loader
      make_local
    end

    def to_s
      str = ""
      @lock.with_read_lock do
        @local_store.each do |k, v|
          value = v[:value]
          str << "|#{k}| in #{v[:namespace]} |#{value_of(value)}|#{value_of(value).class}\n"
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

    def update
      make_local
    end

    def export_api_deltas
      @config_loader.get_api_deltas
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

    # Should client a.b.c see key in namespace a.b? yes
    # Should client a.b.c see key in namespace a.b.c? yes
    # Should client a.b.c see key in namespace a.b.d? no
    # Should client a.b.c see key in namespace ""? yes
    #
    def starts_with_ns?(key_namespace, client_namespace)
      zipped = key_namespace.split(NAMESPACE_DELIMITER).zip(client_namespace.split(NAMESPACE_DELIMITER))
      zipped.map do |k, c|
        (k.nil? || k.empty?) || c == k
      end.all?
    end

    def make_local
      store = {}
      @config_loader.calc_config.each do |prop, value|
        property = prop
        key_namespace = ""

        split = prop.split(NAME_KEY_DELIMITER)

        if split.size > 1
          property = split[1..-1].join(NAME_KEY_DELIMITER)
          key_namespace = split[0]
        end

        if starts_with_ns?(key_namespace, @namespace)
          existing = store[property]
          if existing.nil?
            store[property] = { namespace: key_namespace, value: value }
          elsif existing[:namespace].split(NAMESPACE_DELIMITER).size < key_namespace.split(NAMESPACE_DELIMITER).size
            store[property] = { namespace: key_namespace, value: value }
          end
        end
      end
      @lock.with_write_lock do
        @local_store = store
      end
    end
  end
end
