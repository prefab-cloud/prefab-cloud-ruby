# frozen_string_literal: true

require 'test_helper'

class TestOptions < Minitest::Test
  API_KEY = 'abcdefg'

  def test_api_override_env_var
    assert_equal Prefab::Options::DEFAULT_SOURCES, Prefab::Options.new.sources

    # blank doesn't take effect
    with_env('PREFAB_API_URL_OVERRIDE', '') do
      assert_equal Prefab::Options::DEFAULT_SOURCES, Prefab::Options.new.sources
    end

    # non-blank does take effect
    with_env('PREFAB_API_URL_OVERRIDE', 'https://override.example.com') do
      assert_equal ["https://override.example.com"], Prefab::Options.new.sources
    end
  end

  def test_overriding_sources
    assert_equal Prefab::Options::DEFAULT_SOURCES, Prefab::Options.new.sources

    # a plain string ends up wrapped in an array
    source = 'https://example.com'
    assert_equal [source], Prefab::Options.new(sources: source).sources

    sources = ['https://example.com', 'https://example2.com']
    assert_equal sources, Prefab::Options.new(sources: sources).sources
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

  def test_collect_max_paths_with_collect_logger_counts_false
    options = Prefab::Options.new(collect_max_paths: 100,
                                  collect_logger_counts: false)
    assert_equal 0, options.collect_max_paths
  end

  def test_collect_max_evaluation_summaries
    assert_equal 100_000, Prefab::Options.new.collect_max_evaluation_summaries
    assert_equal 0, Prefab::Options.new(collect_evaluation_summaries: false).collect_max_evaluation_summaries
    assert_equal 3,
                 Prefab::Options.new(collect_max_evaluation_summaries: 3).collect_max_evaluation_summaries
  end

  def test_context_upload_mode_periodic
    options = Prefab::Options.new(context_upload_mode: :periodic_example, context_max_size: 100)
    assert_equal 100, options.collect_max_example_contexts

    options = Prefab::Options.new(context_upload_mode: :none)
    assert_equal 0, options.collect_max_example_contexts
  end

  def test_context_upload_mode_shape_only
    options = Prefab::Options.new(context_upload_mode: :shape_only, context_max_size: 100)
    assert_equal 100, options.collect_max_shapes

    options = Prefab::Options.new(context_upload_mode: :none)
    assert_equal 0, options.collect_max_shapes
  end

  def test_context_upload_mode_none
    options = Prefab::Options.new(context_upload_mode: :none)
    assert_equal 0, options.collect_max_example_contexts

    options = Prefab::Options.new(context_upload_mode: :none)
    assert_equal 0, options.collect_max_shapes
  end
end
