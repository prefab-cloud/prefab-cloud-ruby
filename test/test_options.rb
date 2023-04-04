# frozen_string_literal: true

require 'test_helper'

class TestOptions < Minitest::Test
  API_KEY = 'abcdefg'

  def test_prefab_api_url
    assert_equal 'https://api.prefab.cloud', Prefab::Options.new.prefab_api_url

    with_env 'PREFAB_API_URL', 'https://api.prefab.cloud' do
      assert_equal 'https://api.prefab.cloud', Prefab::Options.new.prefab_api_url
    end

    with_env 'PREFAB_API_URL', 'https://api.prefab.cloud/' do
      assert_equal 'https://api.prefab.cloud', Prefab::Options.new.prefab_api_url
    end
  end

  def test_works_with_named_arguments
    assert_equal API_KEY, Prefab::Options.new(api_key: API_KEY).api_key
  end

  def test_works_with_hash
    assert_equal API_KEY, Prefab::Options.new({ api_key: API_KEY }).api_key
  end

  def test_collect_max_paths
    assert_equal 1000, Prefab::Options.new.collect_max_paths
    assert_equal 100, Prefab::Options.new(collect_max_paths: 100).collect_max_paths
  end

  def test_collect_max_paths_with_local_only
    options = Prefab::Options.new(collect_max_paths: 100,
                                  prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY)
    assert_equal 0, options.collect_max_paths
  end

  def test_collect_max_paths_with_collect_logs_false
    options = Prefab::Options.new(collect_max_paths: 100,
                                  collect_logs: false)
    assert_equal 0, options.collect_max_paths
  end
end
