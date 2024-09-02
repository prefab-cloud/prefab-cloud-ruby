# frozen_string_literal: true

require 'test_helper'

class PretendLdClient
  def get(key, default)
    return "fallback value" if key == "exists in fallback"
    return default if key == "doesn't exist in fallback"
  end
end

class TestConfigClientMigration < Minitest::Test
  def setup
    super

    options = Prefab::Options.new(
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: 'unit_tests',
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY,
      x_use_local_cache: true,
      migration_fallback: -> (key, default=nil) { PretendLdClient.new.get(key, default) }
    )

    @config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
  end

  def test_migration_value
    assert_equal 'fallback value', @config_client.get('exists in fallback')
    assert_equal 'fallback value', @config_client.get('exists in fallback', "unused default")
    assert_equal nil, @config_client.get("doesn't exist in fallback")
    assert_equal 'default value', @config_client.get("doesn't exist in fallback", "default value")
  end
  
  def test_booleans
    assert_equal 'fallback value', @config_client.get('exists in fallback')
    assert_equal 'fallback value', @config_client.get('exists in fallback', "unused default")
    assert_equal nil, @config_client.get("doesn't exist in fallback")
    assert_equal 'default value', @config_client.get("doesn't exist in fallback", "default value")
  end
end