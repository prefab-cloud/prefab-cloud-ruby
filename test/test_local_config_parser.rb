# frozen_string_literal: true

require 'test_helper'

class TestLocalConfigParser < Minitest::Test
  FILE_NAME = 'example-config.yaml'
  DEFAULT_MATCH = 'default'

  def test_parse_int_config
    key = :sample_int
    parsed = Prefab::LocalConfigParser.parse(key, 123, {}, FILE_NAME)[key]
    config = parsed[:config]

    assert_equal FILE_NAME, parsed[:source]
    assert_equal DEFAULT_MATCH, parsed[:match]
    assert_equal :CONFIG, config.config_type
    assert_equal key.to_s, config.key
    assert_equal 1, config.rows.size
    assert_equal 1, config.rows[0].values.size
    assert_equal 123, config.rows[0].values[0].value.int
  end

  def test_flag_with_a_value
    key = :flag_with_a_value
    value = stringify_keys({ feature_flag: true, value: 'all-features' })
    parsed = Prefab::LocalConfigParser.parse(key, value, {}, FILE_NAME)[key]
    config = parsed[:config]

    assert_equal FILE_NAME, parsed[:source]
    assert_equal key, parsed[:match]
    assert_equal :FEATURE_FLAG, config.config_type
    assert_equal key.to_s, config.key
    assert_equal 1, config.rows.size
    assert_equal 1, config.rows[0].values.size

    value_row = config.rows[0].values[0]
    assert_equal 'all-features', Prefab::ConfigValueUnwrapper.deepest_value(value_row.value, key, {}).unwrap
  end

  def test_flag_in_user_key
    key = :flag_in_user_key
    value = stringify_keys({ 'feature_flag': 'true', value: true,
                             criterion: { operator: 'PROP_IS_ONE_OF', property: 'user.key', values: %w[abc123 xyz987] } })
    parsed = Prefab::LocalConfigParser.parse(key, value, {}, FILE_NAME)[key]
    config = parsed[:config]

    assert_equal FILE_NAME, parsed[:source]
    assert_equal key, parsed[:match]
    assert_equal :FEATURE_FLAG, config.config_type
    assert_equal key.to_s, config.key
    assert_equal 1, config.rows.size
    assert_equal 1, config.rows[0].values.size
    assert_equal 1, config.rows[0].values[0].criteria.size

    value_row = config.rows[0].values[0]
    assert_equal true, Prefab::ConfigValueUnwrapper.deepest_value(value_row.value, key, {}).unwrap

    assert_equal 'user.key', value_row.criteria[0].property_name
    assert_equal :PROP_IS_ONE_OF, value_row.criteria[0].operator
    assert_equal %w[abc123 xyz987], value_row.criteria[0].value_to_match.string_list.values
  end

  private

  def stringify_keys(hash)
    deep_transform_keys(hash, &:to_s)
  end

  def deep_transform_keys(hash, &block)
    result = {}
    hash.each do |key, value|
      result[yield(key)] = value.is_a?(Hash) ? deep_transform_keys(value, &block) : value
    end
    result
  end
end
