# frozen_string_literal: true

# rubocop:disable Naming/MethodName
# We're intentionally keeping the UPCASED method names to match the protobuf
# and avoid wasting CPU cycles lowercasing things
module Prefab
  # This class evaluates a config's criteria. `evaluate` returns the value of
  # the first match based on the provided properties.
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
      rtn = evaluate_for_env(@project_env_id, properties) ||
        evaluate_for_env(0, properties)
      Prefab.internal_logger.debug "Eval Key #{@config.key} Result #{rtn&.value} with #{properties.to_h}", "criteria_evaluator" unless @config.config_type == :LOG_LEVEL
      rtn
    end

    def all_criteria_match?(conditional_value, props)
      conditional_value.criteria.all? do |criterion|
        public_send(criterion.operator, criterion, props)
      end
    end

    def IN_SEG(criterion, properties)
      in_segment?(criterion, properties)
    end

    def NOT_IN_SEG(criterion, properties)
      !in_segment?(criterion, properties)
    end

    def ALWAYS_TRUE(_criterion, _properties)
      true
    end

    def PROP_IS_ONE_OF(criterion, properties)
      matches?(criterion, value_from_properties(criterion, properties), properties)
    end

    def PROP_IS_NOT_ONE_OF(criterion, properties)
      !matches?(criterion, value_from_properties(criterion, properties), properties)
    end

    def PROP_ENDS_WITH_ONE_OF(criterion, properties)
      prop_ends_with_one_of?(criterion, value_from_properties(criterion, properties))
    end

    def PROP_DOES_NOT_END_WITH_ONE_OF(criterion, properties)
      !prop_ends_with_one_of?(criterion, value_from_properties(criterion, properties))
    end

    def HIERARCHICAL_MATCH(criterion, properties)
      value = value_from_properties(criterion, properties)
      value&.start_with?(criterion.value_to_match.string)
    end

    def IN_INT_RANGE(criterion, properties)
      value = if criterion.property_name == 'prefab.current-time'
                Time.now.utc.to_i * 1000
              else
                value_from_properties(criterion, properties)
              end

      value && value >= criterion.value_to_match.int_range.start && value < criterion.value_to_match.int_range.end
    end

    def value_from_properties(criterion, properties)
      criterion.property_name == NAMESPACE_KEY ? @namespace : properties.get(criterion.property_name)
    end

    private

    def evaluate_for_env(env_id, properties)
      @config.rows.each_with_index do |row, index|
        next unless row.project_env_id == env_id

        row.values.each_with_index do |conditional_value, value_index|
          next unless all_criteria_match?(conditional_value, properties)

          return Prefab::Evaluation.new(
            config: @config,
            value: conditional_value.value,
            value_index: value_index,
            config_row_index: index,
            context: properties
          )
        end
      end

      nil
    end

    def in_segment?(criterion, properties)
      segment = @resolver.get(criterion.value_to_match.string, properties)

      @base_client.log.info("Segment #{criterion.value_to_match.string} not found") unless segment

      segment&.report_and_return(@base_client.evaluation_summary_aggregator)
    end

    def matches?(criterion, value, properties)
      criterion_value_or_values = Prefab::ConfigValueUnwrapper.deepest_value(criterion.value_to_match, @config.key,
                                                                             properties).unwrap

      case criterion_value_or_values
      when Google::Protobuf::RepeatedField
        # we to_s the value from properties for comparison because the
        # criterion_value_or_values is a list of strings
        criterion_value_or_values.include?(value.to_s)
      else
        criterion_value_or_values == value
      end
    end

    def prop_ends_with_one_of?(criterion, value)
      return false unless value

      criterion.value_to_match.string_list.values.any? do |ending|
        value.end_with?(ending)
      end
    end
  end
end
# rubocop:enable Naming/MethodName
