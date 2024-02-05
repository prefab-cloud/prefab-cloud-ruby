# frozen_string_literal: true

require 'test_helper'

class TestConfigClient < Minitest::Test
  def setup
    super
    options = Prefab::Options.new(
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: 'unit_tests',
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY,
      x_use_local_cache: true,
    )

    @config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
  end

  def test_load
    assert_equal 'test sample value', @config_client.get('sample')
    assert_equal 123, @config_client.get('sample_int')
    assert_equal 12.12, @config_client.get('sample_double')
    assert_equal true, @config_client.get('sample_bool')
    assert_equal :ERROR, @config_client.get('log-level.app')
  end

  def test_initialization_timeout_error
    options = Prefab::Options.new(
      api_key: '123-ENV-KEY-SDK',
      initialization_timeout_sec: 0.01
    )

    err = assert_raises(Prefab::Errors::InitializationTimeoutError) do
      Prefab::Client.new(options).config_client.get('anything')
    end

    assert_match(/couldn't initialize in 0.01 second timeout/, err.message)
  end

  def test_prefab_envs_is_forgiving
    assert_equal ['my_env'], Prefab::Options.new(
      prefab_envs: 'my_env'
    ).prefab_envs

    assert_equal %w[my_env a_second_env], Prefab::Options.new(
      prefab_envs: %w[my_env a_second_env]
    ).prefab_envs
  end

  def test_prefab_envs_env_var
    ENV['PREFAB_ENVS'] = 'one,two'
    assert_equal %w[one two], Prefab::Options.new.prefab_envs
  end

  def test_invalid_api_key_error
    options = Prefab::Options.new(
      api_key: ''
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get('anything')
    end

    assert_match(/No API key/, err.message)

    options = Prefab::Options.new(
      api_key: 'invalid'
    )

    err = assert_raises(Prefab::Errors::InvalidApiKeyError) do
      Prefab::Client.new(options).config_client.get('anything')
    end

    assert_match(/format is invalid/, err.message)
  end

  def test_caching
    @config_client.send(:cache_configs,
                        PrefabProto::Configs.new(configs:
                                                   [PrefabProto::Config.new(key: 'test', id: 1,
                                                                            rows: [PrefabProto::ConfigRow.new(
                                                                              values: [
                                                                                PrefabProto::ConditionalValue.new(
                                                                                  value: PrefabProto::ConfigValue.new(string: "test value")
                                                                                )
                                                                              ]
                                                                            )])],
                                                 config_service_pointer: PrefabProto::ConfigServicePointer.new(project_id: 3, project_env_id: 5)))
    @config_client.send(:load_cache)
    assert_equal "test value", @config_client.get("test")
  end

  def test_cache_path_respects_xdg
    options = Prefab::Options.new(
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY,
      x_use_local_cache: true,
      api_key: "123-ENV-KEY-SDK",)

    config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
    assert_equal "#{Dir.home}/.cache/prefab.cache.123.json", config_client.send(:cache_path)

    with_env('XDG_CACHE_HOME', '/tmp') do
      config_client = Prefab::ConfigClient.new(MockBaseClient.new(options), 10)
      assert_equal "/tmp/prefab.cache.123.json", config_client.send(:cache_path)
    end
  end

end
