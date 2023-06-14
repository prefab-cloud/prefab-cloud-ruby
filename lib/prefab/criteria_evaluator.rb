# frozen_string_literal: true

module Prefab
  class CriteriaEvaluator
    NAMESPACE_KEY = 'NAMESPACE'
    NO_MATCHING_ROWS = [].freeze

    def initialize(config, project_env_id:, resolver:, namespace:, base_client:)
      @config = config
      @project_env_id = project_env_id
      @resolver = resolver
      @namespace = namespace
      @base_client = base_client
    end

    def evaluate(properties)
      matching_environment_row_values.each do |conditional_value|
        return conditional_value.value if all_criteria_match?(conditional_value, properties)
      end

      default_row_values.each do |conditional_value|
        return conditional_value.value if all_criteria_match?(conditional_value, properties)
      end

      nil
    end

    def all_criteria_match?(conditional_value, props)
      conditional_value.criteria.all? do |criterion|
        evaluate_criteron(criterion, props)
      end
    end

    def evaluate_criteron(criterion, properties)
      case criterion.operator
      when :IN_SEG
        return in_segment?(criterion, properties)
      when :NOT_IN_SEG
        return !in_segment?(criterion, properties)
      when :ALWAYS_TRUE
        return true
      end

      value_from_properties = criterion.property_name === NAMESPACE_KEY ? @namespace : properties.get(criterion.property_name)

      case criterion.operator
      when :PROP_IS_ONE_OF
        matches?(criterion, value_from_properties, properties)
      when :PROP_IS_NOT_ONE_OF
        !matches?(criterion, value_from_properties, properties)
      when :PROP_ENDS_WITH_ONE_OF
        return false unless value_from_properties

        criterion.value_to_match.string_list.values.any? do |ending|
          value_from_properties.end_with?(ending)
        end
      when :PROP_DOES_NOT_END_WITH_ONE_OF
        return true unless value_from_properties

        criterion.value_to_match.string_list.values.none? do |ending|
          value_from_properties.end_with?(ending)
        end
      when :HIERARCHICAL_MATCH
        value_from_properties && value_from_properties.start_with?(criterion.value_to_match.string)
      else
        @base_client.log.info("Unknown Operator: #{criterion.operator}")
        false
      end
    end

    private

    def matching_environment_row_values
      @config.rows.find { |row| row.project_env_id == @project_env_id }&.values || NO_MATCHING_ROWS
    end

    def default_row_values
      @config.rows.find { |row| row.project_env_id != @project_env_id }&.values || NO_MATCHING_ROWS
    end

    def in_segment?(criterion, properties)
      segment = @resolver.get(criterion.value_to_match.string, properties)

      if !segment
        @base_client.log.info( "Segment #{criterion.value_to_match.string} not found")
      end

      segment&.bool
    end

    def matches?(criterion, value_from_properties, properties)
      criterion_value_or_values = Prefab::ConfigValueUnwrapper.unwrap(criterion.value_to_match, @config.key, properties)

      case criterion_value_or_values
      when Google::Protobuf::RepeatedField
        # we to_s the value from properties for comparison because the
        # criterion_value_or_values is a list of strings
        criterion_value_or_values.include?(value_from_properties.to_s)
      else
        criterion_value_or_values == value_from_properties
      end
    end
  end
end
