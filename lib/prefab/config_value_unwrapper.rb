# frozen_string_literal: true

module Prefab
  class ConfigValueUnwrapper
    def self.unwrap(config_value, config_key, properties)
      return nil unless config_value

      case config_value.type
      when :int, :string, :double, :bool, :log_level
        config_value.public_send(config_value.type)
      when :string_list
        config_value.string_list.values
      when :weighted_values
        lookup_key = properties[Prefab::CriteriaEvaluator::LOOKUP_KEY]
        weights = config_value.weighted_values.weighted_values
        value = Prefab::WeightedValueResolver.new(weights, config_key, lookup_key).resolve
        unwrap(value.value, config_key, properties)
      else
        raise "Unknown type: #{config_value.type}"
      end
    end
  end
end
