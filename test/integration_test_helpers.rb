# frozen_string_literal: true

module IntegrationTestHelpers
  SUBMODULE_PATH = 'test/prefab-cloud-integration-test-data'
  RAISE_IF_NO_TESTS_FOUND = ENV['PREFAB_INTEGRATION_TEST_RAISE'] == 'true'

  def self.find_integration_tests
    version = find_integration_test_version

    files = find_versioned_test_files(version)

    if files.none?
      message = "No integration tests found for version: #{version}"
      raise message if RAISE_IF_NO_TESTS_FOUND

      puts message
    end

    files
  end

  def self.find_integration_test_version
    File.read(File.join(SUBMODULE_PATH, 'version')).strip
  rescue StandardError => e
    puts "No version found for integration tests: #{e.message}"
  end

  def self.find_versioned_test_files(version)
    if version.nil?
      []
    else
      Dir[File.join(SUBMODULE_PATH, "tests/#{version}/**/*")]
        .select { |file| file =~ /\.ya?ml$/ }
    end
  end

  def self.prepare_post_data(it)
    case it.aggregator
    when "log_path"
      aggregator = it.test_client.log_path_aggregator

      it.data.each do |(path, data)|
        data.each_with_index do |count, severity|
          count.times { aggregator.push(path, severity) }
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

      it.data.each do |key|
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
              conditional_value_index: data["summary"]["conditional_value_index"],
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

      it.data.each do |hash|
        aggregator.record(Prefab::Context.new(hash))
      end

      expected_data = []
      it.expected_data.each do |data|
        expected_data << PrefabProto::ExampleContext.new(
          timestamp: 0,
          contextSet: PrefabProto::ContextSet.new(
            contexts: data.map do |(k, vs)|
              PrefabProto::Context.new(
                type: k,
                values: vs.map do |v|
                  [v["key"], PrefabProto::ConfigValue.new(v["value_type"] => v["value"])]
                end.to_h
              )
            end
          )
        )
      end
      [aggregator, ->(data) { data.events[0].example_contexts.examples.each { |e| e.timestamp = 0 } }, expected_data]
    else
      puts "unknown aggregator #{it.aggregator}"
    end
  end

  def self.with_parent_context_maybe(context, &block)
    if context
      Prefab::Context.with_context(context, &block)
    else
      yield
    end
  end
end
