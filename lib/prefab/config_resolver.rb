module Prefab
  class ConfigResolver
    include Prefab::ConfigHelper
    NAMESPACE_DELIMITER = ".".freeze

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @environment = base_client.environment
      @namespace = base_client.namespace
      @config_loader = config_loader
      make_local
    end

    def to_s
      str = ""
      @lock.with_read_lock do
        @local_store.each do |k, v|
          value = v[:value]
          str << "|#{k}| from #{v[:match]} |#{value_of(value)}|#{value_of(value).class}\n"
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
      @config_loader.calc_config.each do |key, delta|
        # start with the top level default
        to_store = { match: "default", value: delta.default }
        if delta.envs.any?
          env_values = delta.envs.select { |e| e.environment == @environment }

          # do we have and env_values that match our env?
          if env_values.any?
            env_value = env_values.first

            # override the top level default with env default
            to_store = { match: "env_default", env: env_value.environment, value: env_value.default }

            if env_value.namespace_values.any?
              # check all namespace_values for match
              env_value.namespace_values.each do |namespace_value|
                (starts_with, count) = starts_with_ns?(namespace_value.namespace, @namespace)
                if starts_with
                  # is this match the best match?
                  if count > (to_store[:match_depth_count] || 0)
                    to_store = { match: namespace_value.namespace, count: count, value: namespace_value.config_value }
                  end
                end
              end
            end
          end
        end

        # feature flags are a funny case
        # we only define the variants in the default in order to be DRY
        # but we want to access them in environments, clone them over
        if to_store[:value].type == :feature_flag
          to_store[:value].feature_flag.variants = delta.default.feature_flag.variants
        end

        store[key] = to_store
      end
      @lock.with_write_lock do
        @local_store = store
      end
    end
  end
end
