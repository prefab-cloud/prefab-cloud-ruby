module Prefab
  class ConfigResolver
    include Prefab::ConfigHelper
    NAMESPACE_DELIMITER = ".".freeze

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @project_env_id = base_client.project_env_id
      @namespace = base_client.namespace
      @config_loader = config_loader
      make_local
    end

    def to_s
      str = ""
      @lock.with_read_lock do
        @local_store.each do |k, v|
          if v.nil?
            str<< "|#{k}| tombstone\n"
          else
            value = v[:value]
            str << "|#{k}| from #{v[:match]} |#{value_of(value)}|#{value_of(value).class}\n"
          end
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

    def update
      make_local
    end

    def export_api_deltas
      @config_loader.get_api_deltas
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
      @config_loader.calc_config.each do |key, config|
        sortable = config.rows.map do |row|
          if row.project_env_id != 0
            if row.project_env_id == @project_env_id
              if !row.namespace.empty?
                (starts_with, count) = starts_with_ns?(row.namespace, @namespace)
                # rubocop:disable BlockNesting
                { sortable: 2 + count, match: row.namespace, value: row.value, config: config} if starts_with
              else
                { sortable: 1, match: row.project_env_id, value: row.value, config: config}
              end
            end
          else
            { sortable: 0, match: "default", value: row.value, config: config}
          end
        end.compact
        to_store = sortable.sort_by { |h| h[:sortable] }.last
        store[key] = to_store
      end

      @lock.with_write_lock do
        @local_store = store
      end
    end

    def _get(property)
      @lock.with_read_lock do
        @local_store[property]
      end
    end
  end
end
