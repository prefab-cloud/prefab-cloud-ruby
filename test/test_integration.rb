# frozen_string_literal: true

require 'test_helper'
require 'integration_test_helpers'
require 'integration_test'
require 'yaml'

class TestIntegration < Minitest::Test
  IntegrationTestHelpers.find_integration_tests.map do |test_file|
    tests = YAML.load(File.read(test_file))['tests']

    tests.each do |test|
      parent_context = test['context']

      test['cases'].each do |test_case|
        define_method(:"test_#{test['name']}_#{test_case['name']}") do
          it = IntegrationTest.new(test_case)

          IntegrationTestHelpers.with_parent_context_maybe(parent_context) do
            case it.test_type
            when :raise
              err = assert_raises(it.expected[:error]) do
                it.test_client.send(it.func, *it.input)
              end
              assert_match(/#{it.expected[:message]}/, err.message)
            when :nil
              assert_nil it.test_client.send(it.func, *it.input)
            when :simple_equality
              if it.func == :enabled?
                flag, _default, context = *it.input
                assert_equal it.expected[:value], it.test_client.send(it.func, flag, context)
              else
                assert_equal it.expected[:value], it.test_client.send(it.func, *it.input)
              end
            when :log_level
              assert_equal it.expected[:value].to_sym, it.test_client.send(it.func, *it.input)
            when :telemetry
              aggregator, get_actual_data, expected = IntegrationTestHelpers.prepare_post_data(it)
              aggregator.sync

              wait_for -> { it.last_post_result&.status == 200 }

              assert it.endpoint == it.last_post_endpoint

              actual = get_actual_data[it.last_data_sent]

              expected.all? do |expected|
                assert actual.include?(expected)
              end
            else
              raise "Unknown test type: #{it.test_type}"
            end
          end
        end
      end
    end
  end
end
