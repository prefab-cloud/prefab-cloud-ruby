# frozen_string_literal: true

require 'test_helper'

class TestClient < Minitest::Test
  LOCAL_ONLY = Prefab::Options::DATASOURCES::LOCAL_ONLY

  PROJECT_ENV_ID = 1
  KEY = 'the-key'
  DEFAULT_VALUE = 'default_value'
  DESIRED_VALUE = 'desired_value'

  IRRELEVANT_DEFAULT_VALUE = 'this should never show up'

  DEFAULT_VALUE_CONFIG = PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
  DESIRED_VALUE_CONFIG = PrefabProto::ConfigValue.new(string: DESIRED_VALUE)

  TRUE_CONFIG = PrefabProto::ConfigValue.new(bool: true)
  FALSE_CONFIG = PrefabProto::ConfigValue.new(bool: false)

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(value: DEFAULT_VALUE_CONFIG)
    ]
  )

  def setup
    @client = new_client
  end

  def test_get
    _, err = capture_io do
      assert_equal 'default', @client.get('does.not.exist', 'default')
      assert_equal 'test sample value', @client.get('sample')
      assert_equal 123, @client.get('sample_int')
    end
    assert_equal '', err
  end

  def test_get_with_default
    # A `false` value is not replaced with the default
    assert_equal false, @client.get('false_value', 'red')

    # A falsy value is not replaced with the default
    assert_equal 0, @client.get('zero_value', 'red')

    # A missing value returns the default
    assert_equal 'buckets', @client.get('missing_value', 'buckets')
  end

  def test_get_with_missing_default
    # it raises by default
    err = assert_raises(Prefab::Errors::MissingDefaultError) do
      assert_nil @client.get('missing_value')
    end

    assert_match(/No value found for key/, err.message)
    assert_match(/on_no_default/, err.message)

    # you can opt-in to return `nil` instead
    client = new_client(on_no_default: Prefab::Options::ON_NO_DEFAULT::RETURN_NIL)
    assert_nil client.get('missing_value')
  end

  def test_enabled
    assert_equal false, @client.enabled?('does_not_exist')
    assert_equal true, @client.enabled?('enabled_flag')
    assert_equal false, @client.enabled?('disabled_flag')
    assert_equal false, @client.enabled?('flag_with_a_value')
  end

  def test_ff_enabled_with_user_key_match
    assert_equal_context_and_jit(false, :enabled?, 'user_key_match', { user: { key: 'jimmy' } })
    assert_equal_context_and_jit(true, :enabled?, 'user_key_match', { user: { key: 'abc123' } })
    assert_equal_context_and_jit(true, :enabled?, 'user_key_match', { user: { key: 'xyz987' } })
  end

  def test_ff_enabled_with_context
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'gmail.com' })
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'prefab.cloud' })
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'example.com' })
  end

  def test_ff_get_with_context
    assert_nil @client.get('just_my_domain', 'abc123', user: { domain: 'gmail.com' })
    assert_equal 'DEFAULT', @client.get('just_my_domain', 'abc123', { user: { domain: 'gmail.com' } }, 'DEFAULT')

    assert_equal_context_and_jit('new-version', :get, 'just_my_domain', { user: { domain: 'prefab.cloud' } })
    assert_equal_context_and_jit('new-version', :get, 'just_my_domain', { user: { domain: 'example.com' } })
  end

  def test_deprecated_no_dot_notation_ff_enabled_with_jit_context
    # with no lookup key
    assert_equal false, @client.enabled?('deprecated_no_dot_notation', { domain: 'gmail.com' })
    assert_equal true, @client.enabled?('deprecated_no_dot_notation', { domain: 'prefab.cloud' })
    assert_equal true, @client.enabled?('deprecated_no_dot_notation', { domain: 'example.com' })

    # with a lookup key
    assert_equal false, @client.enabled?('deprecated_no_dot_notation', 'some-lookup-key', { domain: 'gmail.com' })
    assert_equal true, @client.enabled?('deprecated_no_dot_notation', 'some-lookup-key', { domain: 'prefab.cloud' })
    assert_equal true, @client.enabled?('deprecated_no_dot_notation', 'some-lookup-key', { domain: 'example.com' })
  end

  def test_getting_feature_flag_value
    assert_equal false, @client.enabled?('flag_with_a_value')
    assert_equal 'all-features', @client.get('flag_with_a_value')
  end

  def test_initialization_with_an_options_object
    options_hash = {
      namespace: 'test-namespace',
      prefab_datasources: LOCAL_ONLY
    }

    options = Prefab::Options.new(options_hash)

    client = Prefab::Client.new(options)

    assert_equal client.namespace, 'test-namespace'
  end

  def test_initialization_with_a_hash
    options_hash = {
      namespace: 'test-namespace',
      prefab_datasources: LOCAL_ONLY
    }

    client = Prefab::Client.new(options_hash)

    assert_equal client.namespace, 'test-namespace'
  end

  def test_evaluation_summary_aggregator
    fake_api_key = '123-development-yourapikey-SDK'

    # it is nil by default
    assert_nil Prefab::Client.new(api_key: fake_api_key).evaluation_summary_aggregator

    # it is nil when local_only even if collect_max_evaluation_summaries is true
    assert_nil Prefab::Client.new(prefab_datasources: LOCAL_ONLY,
                                  collect_evaluation_summaries: true).evaluation_summary_aggregator

    # it is nil when collect_max_evaluation_summaries is false
    assert_nil Prefab::Client.new(api_key: fake_api_key,
                                  collect_evaluation_summaries: false).evaluation_summary_aggregator

    # it is not nil when collect_max_evaluation_summaries is true and the datasource is not local_only
    assert_equal Prefab::EvaluationSummaryAggregator,
                 Prefab::Client.new(api_key: fake_api_key,
                                    collect_evaluation_summaries: true).evaluation_summary_aggregator.class
  end

  def test_get_with_basic_value
    config = PrefabProto::Config.new(
      id: 123,
      key: KEY,
      config_type: PrefabProto::ConfigType::CONFIG,
      rows: [
        DEFAULT_ROW,
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    client = new_client(config: config, project_env_id: PROJECT_ENV_ID, collect_evaluation_summaries: :force)

    assert_equal DESIRED_VALUE, client.get(config.key)

    assert_summary client, {
      [KEY, :CONFIG] => {
        {
          config_id: config.id,
          config_row_index: 1,
          selected_value: DESIRED_VALUE_CONFIG,
          conditional_value_index: 0,
          weighted_value_index: nil,
          selected_index: nil
        } => 1
      }
    }
  end

  def test_get_with_weighted_values
    config = PrefabProto::Config.new(
      id: 123,
      key: KEY,
      config_type: PrefabProto::ConfigType::CONFIG,
      rows: [
        DEFAULT_ROW,
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)],
              value: PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 98], ['def', 1],
                                                                                    ['ghi', 1]]))
            )
          ]
        )
      ]
    )

    client = new_client(config: config, project_env_id: PROJECT_ENV_ID, collect_evaluation_summaries: :force)

    2.times do
      assert_equal 'abc', client.get(config.key, IRRELEVANT_DEFAULT_VALUE, context('user' => { 'key' => '1' }))
    end

    3.times do
      assert_equal 'def', client.get(config.key, IRRELEVANT_DEFAULT_VALUE, context('user' => { 'key' => '12' }))
    end

    assert_equal 'ghi', client.get(config.key, IRRELEVANT_DEFAULT_VALUE, context('user' => { 'key' => '4' }))

    assert_summary client, {
      [KEY, :CONFIG] => {
        {
          config_id: config.id,
          config_row_index: 1,
          selected_value: PrefabProto::ConfigValue.new(string: 'abc'),
          conditional_value_index: 0,
          weighted_value_index: 0,
          selected_index: nil
        } => 2,

        {
          config_id: config.id,
          config_row_index: 1,
          selected_value: PrefabProto::ConfigValue.new(string: 'def'),
          conditional_value_index: 0,
          weighted_value_index: 1,
          selected_index: nil
        } => 3,

        {
          config_id: config.id,
          config_row_index: 1,
          selected_value: PrefabProto::ConfigValue.new(string: 'ghi'),
          conditional_value_index: 0,
          weighted_value_index: 2,
          selected_index: nil
        } => 1
      }
    }
  end

  def test_in_seg
    segment_key = 'segment_key'

    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              value: TRUE_CONFIG,
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(value: FALSE_CONFIG)
          ]
        )
      ]
    )

    config = PrefabProto::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,

        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: segment_key)
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    client = new_client(config: [config, segment_config], project_env_id: PROJECT_ENV_ID,
                        collect_evaluation_summaries: :force)

    assert_equal DEFAULT_VALUE, client.get(config.key)
    assert_equal DEFAULT_VALUE,
                 client.get(config.key, IRRELEVANT_DEFAULT_VALUE, user: { email: 'example@prefab.cloud' })
    assert_equal DESIRED_VALUE, client.get(config.key, IRRELEVANT_DEFAULT_VALUE, user: { email: 'example@hotmail.com' })

    assert_summary client, {
      [segment_key, :SEGMENT] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, selected_value: FALSE_CONFIG,
          weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, selected_value: TRUE_CONFIG,
          weighted_value_index: nil, selected_index: nil } => 1
      },
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, selected_value: DEFAULT_VALUE_CONFIG,
          weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, selected_value: DESIRED_VALUE_CONFIG,
          weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_get_log_level
    config = PrefabProto::Config.new(
      id: 999,
      key: 'log-level',
      config_type: PrefabProto::ConfigType::LOG_LEVEL,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)],
              value: PrefabProto::ConfigValue.new(log_level: PrefabProto::LogLevel::DEBUG)
            )
          ]
        )
      ]
    )

    client = new_client(config: config, project_env_id: PROJECT_ENV_ID,
                        collect_evaluation_summaries: :force)

    assert_equal :DEBUG, client.get(config.key, IRRELEVANT_DEFAULT_VALUE)

    # nothing is summarized for log levels
    assert_summary client, {}
  end

  private

  def assert_equal_context_and_jit(expected, method, key, context)
    assert_equal expected, @client.send(method, key, context)

    Prefab::Context.with_context(context) do
      assert_equal expected, @client.send(method, key)
    end
  end
end
