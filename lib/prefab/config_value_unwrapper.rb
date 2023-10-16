# frozen_string_literal: true

module Prefab
  class ConfigValueUnwrapper
    LOG = Prefab::InternalLogger.new(ConfigValueUnwrapper)
    attr_reader :value, :weighted_value_index

    def initialize(value, weighted_value_index = nil)
      @value = value
      @weighted_value_index = weighted_value_index
    end

    def unwrap
      case value.type
      when :int, :string, :double, :bool, :log_level
        value.public_send(value.type)
      when :string_list
        value.string_list.values
      else
        LOG.error "Unknown type: #{config_value.type}"
        raise "Unknown type: #{config_value.type}"
      end
    end

    def self.deepest_value(config_value, config_key, context)
      if config_value&.type == :weighted_values
        value, index = Prefab::WeightedValueResolver.new(
          config_value.weighted_values.weighted_values,
          config_key,
          context.get(config_value.weighted_values.hash_by_property_name)
        ).resolve

        new(deepest_value(value.value, config_key, context).value, index)

      elsif config_value&.type == :provided
        if :ENV_VAR == config_value.provided.source
          raw = ENV[config_value.provided.lookup]
          if raw.nil?
            new(Prefab::ConfigValueWrapper.wrap(""))
          else
            new(Prefab::ConfigValueWrapper.wrap(YAML.load(raw)))
          end
        else
          raise "Unknown Provided Source #{config_value.provided.source}"
        end        
      else
        new(config_value)
      end
    end
  end
end
