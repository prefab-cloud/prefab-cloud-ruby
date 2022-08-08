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

  def test_initialization_timeout_error
    options = Prefab::Options.new(
      api_key: "123-ENV-KEY-SDK",
      initialization_timeout_sec: 0.01,
      logdev: StringIO.new
    )

    err = assert_raises(Prefab::Errors::InitializationTimeoutError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match /couldn't initialize in 0.01 second timeout/, err.message
  end

  def test_invalid_api_key_error
    options = Prefab::Options.new(
      api_key: "",
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match /No API key/, err.message

    options = Prefab::Options.new(
      api_key: "invalid",
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get("anything")
    end

    assert_match /format is invalid/, err.message
  end
end
