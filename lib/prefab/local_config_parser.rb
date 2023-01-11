# frozen_string_literal: true

module Prefab
  class LocalConfigParser
    class << self
      def parse(key, value, config, file)
        if value.instance_of?(Hash)
          if value['feature_flag']
            config[key] = feature_flag_config(file, key, value)
          else
            value.each do |nest_key, nest_value|
              nested_key = "#{key}.#{nest_key}"
              nested_key = key if nest_key == '_'
              parse(nested_key, nest_value, config, file)
            end
          end
        else
          config[key] = {
            source: file,
            match: 'default',
            config: Prefab::Config.new(
              config_type: :CONFIG,
              key: key,
              rows: [
                Prefab::ConfigRow.new(values: [
                                        Prefab::ConditionalValue.new(value: value_from(key, value))
                                      ])
              ]
            )
          }
        end

        config
      end

      def value_from(key, raw)
        case raw
        when String
          if key.to_s.start_with? Prefab::LoggerClient::BASE_KEY
            prefab_log_level_resolve = Prefab::LogLevel.resolve(raw.upcase.to_sym) || Prefab::LogLevel::NOT_SET_LOG_LEVEL
            { log_level: prefab_log_level_resolve }
          else
            { string: raw }
          end
        when Integer
          { int: raw }
        when TrueClass, FalseClass
          { bool: raw }
        when Float
          { double: raw }
        end
      end

      def feature_flag_config(file, key, value)
        criterion = (parse_criterion(value['criterion']) if value['criterion'])

        variant = Prefab::ConfigValue.new(value_from(key, value['value']))

        row = Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              criteria: [criterion].compact,
              value: Prefab::ConfigValue.new(
                weighted_values: Prefab::WeightedValues.new(weighted_values: [
                                                              Prefab::WeightedValue.new(
                                                                weight: 1000,
                                                                value: variant
                                                              )
                                                            ])
              )
            )
          ]
        )

        raise Prefab::Error, "Feature flag config `#{key}` #{file} must have a `value`" unless value.key?('value')

        {
          source: file,
          match: key,
          config: Prefab::Config.new(
            config_type: :FEATURE_FLAG,
            key: key,
            allowable_values: [variant],
            rows: [row]
          )
        }
      end

      def parse_criterion(criterion)
        Prefab::Criterion.new(operator: criterion['operator'],
                              property_name: parse_property(criterion),
                              value_to_match: parse_value_to_match(criterion['values']))
      end

      def parse_property(criterion)
        if criterion['operator'] == 'LOOKUP_KEY_IN'
          Prefab::CriteriaEvaluator::LOOKUP_KEY
        else
          criterion['property']
        end
      end

      def parse_value_to_match(values)
        # TODO: handle more value types
        raise "Can't handle #{values}" unless values.instance_of?(Array)

        Prefab::ConfigValue.new(string_list: Prefab::StringList.new(values: values))
      end
    end
  end
end
