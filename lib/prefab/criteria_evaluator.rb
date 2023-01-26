# frozen_string_literal: true

module Prefab
  class CriteriaEvaluator
    LOOKUP_KEY = 'LOOKUP'
    NAMESPACE_KEY = 'NAMESPACE'
    NO_MATCHING_ROWS = [].freeze

    def initialize(config, project_env_id:, resolver:, base_client:)
      @config = config
      @project_env_id = project_env_id
      @resolver = resolver
      @base_client = base_client
    end

    def evaluate(properties)
      # TODO: optimize this and perhaps do it elsewhere
      props = properties.transform_keys(&:to_s)

      matching_environment_row_values.each do |conditional_value|
        # TODO: merge in properties from the environment_row?
        return conditional_value.value if all_criteria_match?(conditional_value.criteria, props)
      end

      default_row_values.each do |conditional_value|
        # TODO: merge in properties from the environment_row?
        return conditional_value.value if all_criteria_match?(conditional_value.criteria, props)
      end

      nil
    end

    def all_criteria_match?(criteria, props)
      criteria.all? do |criterion|
        evaluate_criteron(criterion, props)
      end
    end

    def evaluate_criteron(criterion, properties)
      value_from_properites = properties[criterion.property_name]

      case criterion.operator
      when :LOOKUP_KEY_IN, :PROP_IS_ONE_OF
        matches?(criterion, value_from_properites, properties)
      when :LOOKUP_KEY_NOT_IN, :PROP_IS_NOT_ONE_OF
        !matches?(criterion, value_from_properites, properties)
      when :IN_SEG
        segment_criteria = @resolver.segment_criteria(criterion.value_to_match.string)
        return true if segment_criteria.nil? # TODO: right?

        all_criteria_match?(segment_criteria, properties)
      when :NOT_IN_SEG
        segment_criteria = @resolver.segment_criteria(criterion.value_to_match.string)
        return false if segment_criteria.nil? # TODO: right?

        !all_criteria_match?(segment_criteria, properties)
      when :PROP_ENDS_WITH_ONE_OF
        return false unless value_from_properites

        criterion.value_to_match.string_list.values.any? do |ending|
          value_from_properites.end_with?(ending)
        end
      when :PROP_DOES_NOT_END_WITH_ONE_OF
        return true unless value_from_properites

        criterion.value_to_match.string_list.values.none? do |ending|
          value_from_properites.end_with?(ending)
        end
      when :HIERARCHICAL_MATCH
        value_from_properites.start_with?(criterion.value_to_match.string)
      else
        @base_client.log.info("Unknown Operator: #{criteria.operator}")
        false
      end
    end

    private

    def matches?(criterion, value_from_properites, properties)
      criterion_value_or_values = Prefab::ConfigValueUnwrapper.unwrap(criterion.value_to_match, @config.key, properties)

      case criterion_value_or_values
      when Google::Protobuf::RepeatedField
        criterion_value_or_values.include?(value_from_properites)
      else
        criterion_value_or_values == value_from_properites
      end
    end

    def matching_environment_row_values
      @config.rows.find { |row| row.project_env_id == @project_env_id }&.values || NO_MATCHING_ROWS
    end

    def default_row_values
      @config.rows.find { |row| row.project_env_id != @project_env_id }&.values || NO_MATCHING_ROWS
    end
  end
end
