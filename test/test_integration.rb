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

          with_parent_context_maybe(parent_context) do
            case it.test_type
            when :raise
              err = assert_raises(it.expected[:error]) do
                it.test_client.send(it.func, *it.input)
              end
              assert_match(/#{it.expected[:message]}/, err.message)
            when :nil
              assert_nil it.test_client.send(it.func, *it.input)
            when :feature_flag
              flag, context = *it.input
              assert_equal it.expected[:value], it.test_client.send(it.func, flag, context)
            when :simple_equality
              assert_equal it.expected[:value], it.test_client.send(it.func, *it.input)
            when :log_level
              assert_equal it.expected[:value].to_sym, it.test_client.send(it.func, *it.input)
            else
              raise "Unknown test type: #{it.test_type}"
            end
          end
        end
      end
    end
  end

  private

  def with_parent_context_maybe(context, &block)
    if context
      Prefab::Context.with_context(context, &block)
    else
      yield
    end
  end
end
