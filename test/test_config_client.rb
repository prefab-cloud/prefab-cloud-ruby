# frozen_string_literal: true
require 'test_helper'

class TestConfigClient < Minitest::Test
  def setup
    options = Prefab::Options.new(
      prefab_config_override_dir: "none",
      prefab_config_classpath_dir: "test",
      defaults_env: "unit_tests",
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    )

    @config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
  end

  def test_load
    assert_equal "test sample value", @config_client.get("sample")
    assert_equal 123, @config_client.get("sample_int")
  end
end
