# frozen_string_literal: true

require 'test_helper'

class TestConfigValueWrapper < Minitest::Test
  def test_wrap_integer
    result = Prefab::ConfigValueWrapper.wrap(42)
    assert_instance_of PrefabProto::ConfigValue, result
    assert_equal 42, result.int
  end

  def test_wrap_float
    result = Prefab::ConfigValueWrapper.wrap(3.14)
    assert_instance_of PrefabProto::ConfigValue, result
    assert_equal 3.14, result.double
  end

  def test_wrap_boolean_true
    result = Prefab::ConfigValueWrapper.wrap(true)
    assert_instance_of PrefabProto::ConfigValue, result
    assert_equal true, result.bool
  end

  def test_wrap_boolean_false
    result = Prefab::ConfigValueWrapper.wrap(false)
    assert_instance_of PrefabProto::ConfigValue, result
    assert_equal false, result.bool
  end

  def test_wrap_array
    result = Prefab::ConfigValueWrapper.wrap(['one', 'two', 'three'])
    assert_instance_of PrefabProto::ConfigValue, result
    assert_instance_of PrefabProto::StringList, result.string_list
    assert_equal ['one', 'two', 'three'], result.string_list.values
  end

  def test_wrap_string
    result = Prefab::ConfigValueWrapper.wrap('hello')
    assert_instance_of PrefabProto::ConfigValue, result
    assert_equal 'hello', result.string
  end
end
