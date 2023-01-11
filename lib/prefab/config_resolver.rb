# frozen_string_literal: true

module Prefab
  class ConfigResolver
    attr_accessor :project_env_id # this will be set by the config_client when it gets an API response

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @additional_properties = { Prefab::CriteriaEvaluator::NAMESPACE_KEY => base_client.options.namespace }
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
    end

    def raw(key)
      via_key = @local_store[key]

      via_key ? via_key[:config] : nil
    end

    def get(key, lookup_key, properties = {})
      @lock.with_read_lock do
        raw_config = raw(key)

        return nil unless raw_config

        evaluate(raw(key), lookup_key, properties)
      end
    end

    def evaluate(config, lookup_key, properties = {})
      props = properties.merge(@additional_properties)
      props = props.merge(Prefab::CriteriaEvaluator::LOOKUP_KEY => lookup_key)

      Prefab::CriteriaEvaluator.new(config,
                                    project_env_id: @project_env_id, resolver: self, base_client: @base_client).evaluate(props)
    end

    def segment_criteria(key)
      segment = raw(key)

      return nil unless segment

      segment.rows[0].values[0].value.segment.criteria
    end

    def update
      make_local
    end

    private

    def make_local
      @lock.with_write_lock do
        @local_store = @config_loader.calc_config
      end
    end
  end
end
