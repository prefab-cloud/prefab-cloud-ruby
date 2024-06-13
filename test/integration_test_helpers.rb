# frozen_string_literal: true

module IntegrationTestHelpers
  SUBMODULE_PATH = 'test/prefab-cloud-integration-test-data'
  RAISE_IF_NO_TESTS_FOUND = ENV['PREFAB_INTEGRATION_TEST_RAISE'] == 'true'

  def self.find_integration_tests
    files = find_test_files

    if files.none?
      message = "No integration tests found"
      raise message if RAISE_IF_NO_TESTS_FOUND

      puts message
    end

    files
  end

  def self.find_test_files
    Dir[File.join(SUBMODULE_PATH, "tests/current/**/*")]
      .select { |file| file =~ /\.ya?ml$/ }
  end

  SEVERITY_LOOKUP = Prefab::LogPathAggregator::SEVERITY_KEY.invert

  def self.prepare_post_data(it)
    case it.aggregator
    when "log_path"
      aggregator = it.test_client.log_path_aggregator

      it.data.each do |data|
        data['counts'].each_pair do |severity, count|
          count.times { aggregator.push(data['logger_name'], SEVERITY_LOOKUP[severity]) }
        end
      end

      expected_loggers = Hash.new { |h, k| h[k] = PrefabProto::Logger.new }

      it.expected_data.each do |data|
        data["counts"].each do |(severity, count)|
          expected_loggers[data["logger_name"]][severity] = count
          expected_loggers[data["logger_name"]]["logger_name"] = data["logger_name"]
        end
      end

      [aggregator, ->(data) { data.loggers }, expected_loggers.values]
    when "context_shape"
      aggregator = it.test_client.context_shape_aggregator

      context = Prefab::Context.new(it.data)

      aggregator.push(context)

      expected = it.expected_data.map do |data|
        PrefabProto::ContextShape.new(
          name: data["name"],
          field_types: data["field_types"]
        )
      end

      [aggregator, ->(data) { data.shapes }, expected]
    when "evaluation_summary"
      aggregator = it.test_client.evaluation_summary_aggregator

      aggregator.instance_variable_set("@data", Concurrent::Hash.new)

      it.data["keys"].each do |key|
        it.test_client.get(key)
      end

      expected_data = []
      it.expected_data.each do |data|
        value = if data["value_type"] == "string_list"
                  PrefabProto::StringList.new(values: data["value"])
                else
                  data["value"]
                end
        expected_data << PrefabProto::ConfigEvaluationSummary.new(
          key: data["key"],
          type: data["type"].to_sym,
          counters: [
            PrefabProto::ConfigEvaluationCounter.new(
              count: data["count"],
              config_id: 0,
              selected_value: PrefabProto::ConfigValue.new(data["value_type"] => value),
              config_row_index: data["summary"]["config_row_index"],
              conditional_value_index: data["summary"]["conditional_value_index"] || 0,
              weighted_value_index: data["summary"]["weighted_value_index"],
              reason: :UNKNOWN
            )
          ]
        )
      end

      [aggregator, ->(data) {
                     data.events[0].summaries.summaries.each { |e|
                       e.counters.each { |c|
                         c.config_id = 0
                       }
                     }
                   }, expected_data]
    when "example_contexts"
      aggregator = it.test_client.example_contexts_aggregator

      it.data.each do |key, values|
        aggregator.record(Prefab::Context.new({ key => values }))
      end

      expected_data = []
      it.expected_data.each do |k, vs|
        expected_data << PrefabProto::ExampleContext.new(
          timestamp: 0,
          contextSet: PrefabProto::ContextSet.new(
            contexts: [
              PrefabProto::Context.new(
                type: k,
                values: vs.each_pair.map do |key, value|
                  [key, Prefab::ConfigValueWrapper.wrap(value)]
                end.to_h
              )
            ]
          )
        )
      end
      [aggregator, ->(data) { data.events[0].example_contexts.examples.each { |e| e.timestamp = 0 } }, expected_data]
    else
      puts "unknown aggregator #{it.aggregator}"
    end
  end

  def self.with_block_context_maybe(context, &block)
    if context
      Prefab::Context.with_context(context, &block)
    else
      yield
    end
  end
end
