# frozen_string_literal: true

module Prefab
  class ConfigResolver
    attr_accessor :project_env_id # this will be set by the config_client when it gets an API response

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @config_loader = config_loader
      @project_env_id = 0 # we don't know this yet, it is set from the API results
      @base_client = base_client
      make_local
    end

    def to_s
      str = "\n"
      @lock.with_read_lock do
        @local_store.keys.sort.each do |k|
          v = @local_store[k]
          elements = [k.slice(0..49).ljust(50)]
          if v.nil?
            elements << 'tombstone'
          else
            config = evaluate(v[:config], {})
            value = Prefab::ConfigValueUnwrapper.unwrap(config, k, {})
            elements << value.to_s.slice(0..34).ljust(35)
            elements << value.class.to_s.slice(0..6).ljust(7)
            elements << "Match: #{v[:match]}".slice(0..29).ljust(30)
            elements << "Source: #{v[:source]}"
          end
          str += elements.join(' | ') << "\n"
        end
      end
      str
    rescue StandardError => e
      "Error printing resolved config: #{e.message}"
    end

    def raw(key)
      via_key = @local_store[key]

      via_key ? via_key[:config] : nil
    end

    def get(key, properties = NO_DEFAULT_PROVIDED)
      @lock.with_read_lock do
        raw_config = raw(key)

        return nil unless raw_config

        evaluate(raw(key), properties)
      end
    end

    def evaluate(config, properties = NO_DEFAULT_PROVIDED)
      Prefab::CriteriaEvaluator.new(config,
                                    project_env_id: @project_env_id,
                                    resolver: self,
                                    namespace: @base_client.options.namespace,
                                    base_client: @base_client).evaluate(context(properties))
    end

    def update
      make_local
    end

    private

    def context(properties)
      if properties == NO_DEFAULT_PROVIDED
        Context.current
      elsif properties.is_a?(Context)
        properties
      else
        Context.merge_with_current(properties)
      end
    end

    def make_local
      @lock.with_write_lock do
        @local_store = @config_loader.calc_config
      end
    end
  end
end
