# frozen_string_literal: true

require 'test_helper'

class TestConfigValueUnwrapper < Minitest::Test
  CONFIG_KEY = 'config_key'
  EMPTY_CONTEXT = Prefab::Context.new()

  def test_unwrapping_int
    config_value = PrefabProto::ConfigValue.new(int: 123)
    assert_equal 123, unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_string
    config_value = PrefabProto::ConfigValue.new(string: 'abc')
    assert_equal 'abc', unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_double
    config_value = PrefabProto::ConfigValue.new(double: 1.23)
    assert_equal 1.23, unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_bool
    config_value = PrefabProto::ConfigValue.new(bool: true)
    assert_equal true, unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)

    config_value = PrefabProto::ConfigValue.new(bool: false)
    assert_equal false, unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_log_level
    config_value = PrefabProto::ConfigValue.new(log_level: :INFO)
    assert_equal :INFO, unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_string_list
    config_value = PrefabProto::ConfigValue.new(string_list: PrefabProto::StringList.new(values: %w[a b c]))
    assert_equal %w[a b c], unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  def test_unwrapping_weighted_values
    # single value
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1]]))

    assert_equal 'abc', unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)

    # multiple values, evenly distributed
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 1], ['ghi', 1]]))
    assert_equal 'def', unwrap(config_value, CONFIG_KEY, context_with_key('user:000'))
    assert_equal 'ghi', unwrap(config_value, CONFIG_KEY, context_with_key('user:456'))
    assert_equal 'abc', unwrap(config_value, CONFIG_KEY, context_with_key('user:789'))
    assert_equal 'ghi', unwrap(config_value, CONFIG_KEY, context_with_key('user:888'))

    # multiple values, unevenly distributed
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 99], ['ghi', 1]]))
    assert_equal 'def', unwrap(config_value, CONFIG_KEY, context_with_key('user:123'))
    assert_equal 'def', unwrap(config_value, CONFIG_KEY, context_with_key('user:456'))
    assert_equal 'def', unwrap(config_value, CONFIG_KEY, context_with_key('user:789'))
    assert_equal 'def', unwrap(config_value, CONFIG_KEY, context_with_key('user:012'))
    assert_equal 'ghi', unwrap(config_value, CONFIG_KEY, context_with_key('user:428'))
    assert_equal 'abc', unwrap(config_value, CONFIG_KEY, context_with_key('user:548'))
  end

  def test_unwrapping_provided_values
    with_env('ENV_VAR_NAME', 'unit test value')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)
      assert_equal 'unit test value', unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
    end
  end

  def test_unwrapping_provided_values_of_type_array
    with_env('ENV_VAR_NAME', '["bob","cary"]')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)
      assert_equal ["bob", "cary"], unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
    end
  end

  def test_unwrapping_provided_values_with_missing_env_var
    value = PrefabProto::Provided.new(
      source: :ENV_VAR,
      lookup: "NON_EXISTENT_ENV_VAR_NAME"
    )
    config_value = PrefabProto::ConfigValue.new(provided: value)
    assert_equal '', unwrap(config_value, CONFIG_KEY, EMPTY_CONTEXT)
  end

  private

  def context_with_key(key)
    Prefab::Context.new(user: { key: key })
  end

  def unwrap(config_value, config_key, context)
    Prefab::ConfigValueUnwrapper.deepest_value(config_value, config_key, context).unwrap
  end
end
