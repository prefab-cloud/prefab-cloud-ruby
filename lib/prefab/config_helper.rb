# frozen_string_literal: true

module Prefab
  module ConfigHelper
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
      when :segment
        config_value.segment
      when :log_level
        config_value.log_level
      end
    end

    def value_of_variant(feature_flag_variant)
      return feature_flag_variant.string if feature_flag_variant.has_string?
      return feature_flag_variant.int if feature_flag_variant.has_int?
      return feature_flag_variant.double if feature_flag_variant.has_double?
      return feature_flag_variant.bool if feature_flag_variant.has_bool?

      nil
    end
  end
end
