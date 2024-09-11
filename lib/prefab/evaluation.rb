# frozen_string_literal: true

module Prefab
  # Records the result of evaluating a config's criteria and forensics for reporting
  class Evaluation
    attr_reader :value, :context

    def initialize(config:, value:, value_index:, config_row_index:, context:, resolver:)
      @config = config
      @value = value
      @value_index = value_index
      @config_row_index = config_row_index
      @context = context
      @resolver = resolver
    end

    def unwrapped_value
      deepest_value.unwrap
    end

    def reportable_value
      deepest_value.reportable_value
    end

    def report_and_return(evaluation_summary_aggregator)
      report(evaluation_summary_aggregator)

      unwrapped_value
    end

    def js_value
      case @config.value_type
      when :STRING_LIST
        { stringList: deepest_value.raw_config_value.string_list.values.to_a }
      when :DURATION
        value = Prefab::Duration.new(deepest_value.raw_config_value.duration.definition).as_json
        { duration: value }
      when :JSON
        { json: deepest_value.raw_config_value.json.json }
      else
        deepest_value.raw_config_value
      end
    end

    def to_js_payload
      {
        value: js_value,
        configEvaluationMetadata: {
          type: @config.config_type,
          id: @config.id.to_s,
          valueType: @config.value_type,
          configRowIndex: @config_row_index,
          conditionalValueIndex: @value_index,
          weightedValueIndex: deepest_value.weighted_value_index
        }.compact
      }
    end

    private

    def report(evaluation_summary_aggregator)
      return if @config.config_type == :LOG_LEVEL

      evaluation_summary_aggregator&.record(
        config_key: @config.key,
        config_type: @config.config_type,
        counter: {
          config_id: @config.id,
          config_row_index: @config_row_index,
          conditional_value_index: @value_index,
          selected_value: deepest_value.reportable_wrapped_value,
          weighted_value_index: deepest_value.weighted_value_index,
          selected_index: nil # TODO
        })
    end

    def deepest_value
      @deepest_value ||= Prefab::ConfigValueUnwrapper.deepest_value(@value, @config, @context, @resolver)
    end
  end
end
