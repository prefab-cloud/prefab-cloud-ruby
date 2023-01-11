# frozen_string_literal: true

require 'test_helper'

class TestConfigValueUnwrapper < Minitest::Test
  CONFIG_KEY = 'config_key'

  def test_unwrapping_int
    config_value = Prefab::ConfigValue.new(int: 123)
    assert_equal 123, Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_string
    config_value = Prefab::ConfigValue.new(string: 'abc')
    assert_equal 'abc', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_double
    config_value = Prefab::ConfigValue.new(double: 1.23)
    assert_equal 1.23, Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_bool
    config_value = Prefab::ConfigValue.new(bool: true)
    assert_equal true, Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})

    config_value = Prefab::ConfigValue.new(bool: false)
    assert_equal false, Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_log_level
    config_value = Prefab::ConfigValue.new(log_level: :INFO)
    assert_equal :INFO, Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_string_list
    config_value = Prefab::ConfigValue.new(string_list: Prefab::StringList.new(values: %w[a b c]))
    assert_equal %w[a b c], Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})
  end

  def test_unwrapping_weighted_values
    # single value
    config_value = Prefab::ConfigValue.new(weighted_values: weighted_values([['abc', 1]]))
    assert_equal 'abc', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, {})

    # multiple values, evenly distributed
    config_value = Prefab::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 1], ['ghi', 1]]))
    assert_equal 'ghi', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:123'))
    assert_equal 'ghi', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:456'))
    assert_equal 'abc', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:789'))
    assert_equal 'def', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:012'))

    # multiple values, unevenly distributed
    config_value = Prefab::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 99], ['ghi', 1]]))
    assert_equal 'def', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:123'))
    assert_equal 'def', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:456'))
    assert_equal 'def', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:789'))
    assert_equal 'def', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:012'))

    assert_equal 'ghi', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:103'))
    assert_equal 'abc', Prefab::ConfigValueUnwrapper.unwrap(config_value, CONFIG_KEY, lookup_properties('user:119'))
  end

  private

  def weighted_values(values_and_weights)
    values = values_and_weights.map do |value, weight|
      weighted_value(value, weight)
    end

    Prefab::WeightedValues.new(weighted_values: values)
  end

  def weighted_value(string, weight)
    Prefab::WeightedValue.new(
      value: Prefab::ConfigValue.new(string: string), weight: weight
    )
  end

  def lookup_properties(lookup_key)
    { Prefab::CriteriaEvaluator::LOOKUP_KEY => lookup_key }
  end
end
