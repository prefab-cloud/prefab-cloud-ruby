# frozen_string_literal: true
require 'test_helper'

class TestConfigClient < Minitest::Test
  def setup
    options = Prefab::Options.new(
      prefab_config_override_dir: "none",
      prefab_config_classpath_dir: "test",
      prefab_envs: "unit_tests",
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    )

    @config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
  end

  def test_load
    assert_equal "test sample value", @config_client.get("sample")
    assert_equal 123, @config_client.get("sample_int")
    assert_equal 12.12, @config_client.get("sample_double")
    assert_equal true, @config_client.get("sample_bool")
    assert_equal :ERROR, @config_client.get("log-level.app")
  end

  def test_initialization_timeout_error
    options = Prefab::Options.new(
      api_key: "123-ENV-KEY-SDK",
      initialization_timeout_sec: 0.01,
      logdev: StringIO.new
    )

    err = assert_raises(Prefab::Errors::InitializationTimeoutError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match(/couldn't initialize in 0.01 second timeout/, err.message)
  end

  def test_prefab_envs_is_forgiving
    assert_equal ["my_env"], Prefab::Options.new(
      prefab_envs: "my_env",
    ).prefab_envs

    assert_equal ["my_env", "a_second_env"], Prefab::Options.new(
      prefab_envs: ["my_env", "a_second_env"],
    ).prefab_envs
  end

  def test_prefab_envs_env_var
    ENV["PREFAB_ENVS"] = "one,two"
    assert_equal ["one", "two"], Prefab::Options.new().prefab_envs
  end

  def test_invalid_api_key_error
    options = Prefab::Options.new(
      api_key: "",
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match(/No API key/, err.message)

    options = Prefab::Options.new(
      api_key: "invalid",
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match(/format is invalid/, err.message)
  end
end
