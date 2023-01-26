# frozen_string_literal: true

require 'test_helper'

class TestFeatureFlagClient < Minitest::Test
  DEFAULT = 'default'

  def test_feature_is_on
    ff_client = new_client

    assert_equal false, ff_client.feature_is_on?('something-that-does-not-exist')
    assert_equal false, ff_client.feature_is_on?('disabled_flag')
    assert_equal true, ff_client.feature_is_on?('enabled_flag')
    assert_equal false, ff_client.feature_is_on?('flag_with_a_value')
  end

  def test_feature_is_on_for
    ff_client = new_client

    assert_equal false, ff_client.feature_is_on_for?('something-that-does-not-exist', 'irrelevant')
    assert_equal false, ff_client.feature_is_on_for?('in_lookup_key', 'not-included')
    assert_equal true, ff_client.feature_is_on_for?('in_lookup_key', 'abc123')
    assert_equal true, ff_client.feature_is_on_for?('in_lookup_key', 'xyz987')
  end

  def test_get
    ff_client = new_client

    # No default
    assert_equal false, ff_client.get('something-that-does-not-exist')
    assert_equal false, ff_client.get('disabled_flag')
    assert_equal true, ff_client.get('enabled_flag')
    assert_equal 'all-features', ff_client.get('flag_with_a_value')

    # with defaults
    assert_equal DEFAULT, ff_client.get('something-that-does-not-exist', default: DEFAULT)
    assert_equal false, ff_client.get('disabled_flag', default: DEFAULT)
    assert_equal true, ff_client.get('enabled_flag', default: DEFAULT)
    assert_equal 'all-features', ff_client.get('flag_with_a_value', default: DEFAULT)
  end

  private

  def new_client(overrides = {})
    options = Prefab::Options.new(**{
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: ['unit_tests'],
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    }.merge(overrides))

    Prefab::Client.new(options).feature_flag_client
  end
end
