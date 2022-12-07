# frozen_string_literal: true
require 'test_helper'
require 'integration_test_helpers'
require 'integration_test'
require 'yaml'

class TestIntegration < Minitest::Test

  IntegrationTestHelpers.find_integration_tests().map do |test_file|
    tests = YAML.load(File.read(test_file))["tests"]

    tests.each do |test|
      define_method(:"test_#{test["name"]}") do
        it = IntegrationTest.new(test)

        case it.test_type
        when :raise
          err = assert_raises(it.expected[:error]) do
            it.test_client.send(it.func, *it.input)
          end
          assert_match(/#{it.expected[:message]}/, err.message)
        when :nil
          assert_nil it.test_client.send(it.func, *it.input)
        when :feature_flag
          flag, lookup_key, attributes = *it.input
          assert_equal it.expected[:value], it.test_client.send(it.func, flag, lookup_key, attributes: attributes)
        when :simple_equality
          assert_equal it.expected[:value], it.test_client.send(it.func, *it.input)
        end
      end
    end
  end
end

