module Prefab
  class ConfigResolver
    include Prefab::ConfigHelper
    NAMESPACE_DELIMITER = ".".freeze

    attr_accessor :project_env_id # this will be set by the config_client when it gets an API response

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @namespace = base_client.namespace
      @config_loader = config_loader
      @project_env_id = 0
      make_local
    end

    def to_s
      str = ""
      @lock.with_read_lock do
        @local_store.each do |k, v|
          elements = [k.slice(0..59).ljust(60)]
          if v.nil?
            elements << "tombstone"
          else
            value = v[:value]
            elements << value_of(value).to_s.slice(0..14).ljust(15)
            elements << value_of(value).class.to_s.slice(0..9).ljust(10)
            elements << "Match: #{v[:match]}".slice(0..19).ljust(20)
            elements << "Source: #{v[:source]}"
          end
          str << elements.join(" | ") << "\n"
        end
      end
      str
    end

    def get(property)
      config = _get(property)
      config ? value_of(config[:value]) : nil
    end

    def get_config(property)
      config = _get(property)
      config ? config[:config] : nil
    end

    def _get(key)
      @lock.with_read_lock do
        @local_store[key]
      end
    end

    def update
      make_local
    end

    private

    # Should client a.b.c see key in namespace a.b? yes
    # Should client a.b.c see key in namespace a.b.c? yes
    # Should client a.b.c see key in namespace a.b.d? no
    # Should client a.b.c see key in namespace ""? yes
    #
    def starts_with_ns?(key_namespace, client_namespace)
      zipped = key_namespace.split(NAMESPACE_DELIMITER).zip(client_namespace.split(NAMESPACE_DELIMITER))
      mapped = zipped.map do |k, c|
        (k.nil? || k.empty?) || k == c
      end
      [mapped.all?, mapped.size]
    end

    def make_local
      store = {}
      @config_loader.calc_config.each do |key, config_resolver_obj|
        config = config_resolver_obj[:config]
        sortable = config.rows.map do |row|
          if row.project_env_id != 0
            if row.project_env_id == @project_env_id
              if !row.namespace.empty?
                (starts_with, count) = starts_with_ns?(row.namespace, @namespace)
                # rubocop:disable BlockNesting
                { sortable: 2 + count, match: "nm:#{row.namespace}", value: row.value, config: config} if starts_with
              else
                { sortable: 1, match: "env:#{row.project_env_id}", value: row.value, config: config}
              end
            end
          else
            { sortable: 0, match: "default", value: row.value, config: config}
          end
        end.compact
        to_store = sortable.sort_by { |h| h[:sortable] }.last
        to_store[:source] = config_resolver_obj[:source]
        store[key] = to_store
      end

      @lock.with_write_lock do
        @local_store = store
      end
    end
  end
end
