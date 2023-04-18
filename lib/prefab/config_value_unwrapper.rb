# frozen_string_literal: true

module Prefab
  class ConfigValueUnwrapper
    def self.unwrap(config_value, config_key, context)
      return nil unless config_value

      case config_value.type
      when :int, :string, :double, :bool, :log_level
        config_value.public_send(config_value.type)
      when :string_list
        config_value.string_list.values
      when :weighted_values
        value = Prefab::WeightedValueResolver.new(
          config_value.weighted_values.weighted_values,
          config_key,
          context[config_value.weighted_values.hash_by_property_name]
        ).resolve

        unwrap(value.value, config_key, context)
      else
        raise "Unknown type: #{config_value.type}"
      end
    end
  end
end
