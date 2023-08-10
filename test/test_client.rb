# frozen_string_literal: true

require 'test_helper'

class TestClient < Minitest::Test
  LOCAL_ONLY = Prefab::Options::DATASOURCES::LOCAL_ONLY

  PROJECT_ENV_ID = 1
  KEY = 'the-key'
  DEFAULT_VALUE = 'default_value'
  DESIRED_VALUE = 'desired_value'

  IRRELEVANT = 'this should never show up'

  DEFAULT_VALUE_CONFIG = PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
  DESIRED_VALUE_CONFIG = PrefabProto::ConfigValue.new(string: DESIRED_VALUE)

  TRUE_CONFIG = PrefabProto::ConfigValue.new(bool: true)
  FALSE_CONFIG = PrefabProto::ConfigValue.new(bool: false)

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(value: DEFAULT_VALUE_CONFIG)
    ]
  )

  def test_get
    _, err = capture_io do
      client = new_client
      assert_equal 'default', client.get('does.not.exist', 'default')
      assert_equal 'test sample value', client.get('sample')
      assert_equal 123, client.get('sample_int')
    end
    assert_equal '', err
  end

  def test_get_with_default
    client = new_client
    # A `false` value is not replaced with the default
    assert_equal false, client.get('false_value', 'red')

    # A falsy value is not replaced with the default
    assert_equal 0, client.get('zero_value', 'red')

    # A missing value returns the default
    assert_equal 'buckets', client.get('missing_value', 'buckets')
  end

  def test_get_with_missing_default
    client = new_client
    # it raises by default
    err = assert_raises(Prefab::Errors::MissingDefaultError) do
      assert_nil client.get('missing_value')
    end

    assert_match(/No value found for key/, err.message)
    assert_match(/on_no_default/, err.message)

    # you can opt-in to return `nil` instead
    client = new_client(on_no_default: Prefab::Options::ON_NO_DEFAULT::RETURN_NIL)
    assert_nil client.get('missing_value')
  end

  def test_enabled
    client = new_client
    assert_equal false, client.enabled?('does_not_exist')
    assert_equal true, client.enabled?('enabled_flag')
    assert_equal false, client.enabled?('disabled_flag')
    assert_equal false, client.enabled?('flag_with_a_value')
  end

  def test_ff_enabled_with_user_key_match
    client = new_client

    ctx = { user: { key: 'jimmy' } }
    assert_equal false, client.enabled?('user_key_match', ctx)
    assert_equal false, Prefab::Context.with_context(ctx) { client.enabled?('user_key_match') }

    ctx = { user: { key: 'abc123' } }
    assert_equal true, client.enabled?('user_key_match', ctx)
    assert_equal true, Prefab::Context.with_context(ctx) { client.enabled?('user_key_match') }

    ctx = { user: { key: 'xyz987' } }
    assert_equal true, client.enabled?('user_key_match', ctx)
    assert_equal true, Prefab::Context.with_context(ctx) { client.enabled?('user_key_match') }
  end

  # NOTE: these are all `false` because we're doing a enabled? on a FF with string variants
  # see test_ff_get_with_context for the raw value tests
  def test_ff_enabled_with_context
    client = new_client

    ctx = { user: { domain: 'gmail.com' } }
    assert_equal false, client.enabled?('just_my_domain', ctx)
    assert_equal false, Prefab::Context.with_context(ctx) { client.enabled?('just_my_domain') }

    ctx = { user: { domain: 'prefab.cloud' } }
    assert_equal false, client.enabled?('just_my_domain', ctx)
    assert_equal false, Prefab::Context.with_context(ctx) { client.enabled?('just_my_domain') }

    ctx = { user: { domain: 'example.com' } }
    assert_equal false, client.enabled?('just_my_domain', ctx)
    assert_equal false, Prefab::Context.with_context(ctx) { client.enabled?('just_my_domain') }
  end

  def test_ff_get_with_context
    client = new_client

    ctx = { user: { domain: 'gmail.com' } }
    assert_equal 'DEFAULT', client.get('just_my_domain', 'DEFAULT', ctx)
    assert_equal 'DEFAULT', Prefab::Context.with_context(ctx) { client.get('just_my_domain', 'DEFAULT') }

    ctx = { user: { domain: 'prefab.cloud' } }
    assert_equal 'new-version', client.get('just_my_domain', 'DEFAULT', ctx)
    assert_equal 'new-version', Prefab::Context.with_context(ctx) { client.get('just_my_domain', 'DEFAULT') }

    ctx = { user: { domain: 'example.com' } }
    assert_equal 'new-version', client.get('just_my_domain', 'DEFAULT', ctx)
    assert_equal 'new-version', Prefab::Context.with_context(ctx) { client.get('just_my_domain', 'DEFAULT') }
  end

  def test_deprecated_no_dot_notation_ff_enabled_with_jit_context
    client = new_client
    # with no lookup key
    assert_equal false, client.enabled?('deprecated_no_dot_notation', { domain: 'gmail.com' })
    assert_equal true, client.enabled?('deprecated_no_dot_notation', { domain: 'prefab.cloud' })
    assert_equal true, client.enabled?('deprecated_no_dot_notation', { domain: 'example.com' })

    assert_stderr [
      "[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash.",
      "[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash.",
      "[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash."
    ]
  end

  def test_getting_feature_flag_value
    client = new_client
    assert_equal false, client.enabled?('flag_with_a_value')
    assert_equal 'all-features', client.get('flag_with_a_value')
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
    assert_nil new_client(api_key: fake_api_key).evaluation_summary_aggregator

    # it is nil when local_only even if collect_max_evaluation_summaries is true
    assert_nil new_client(prefab_datasources: LOCAL_ONLY,
                                  collect_evaluation_summaries: true, ).evaluation_summary_aggregator

    # it is nil when collect_max_evaluation_summaries is false
    assert_nil new_client(api_key: fake_api_key,
                                  prefab_datasources: :all,
                                  collect_evaluation_summaries: false).evaluation_summary_aggregator

    # it is not nil when collect_max_evaluation_summaries is true and the datasource is not local_only
    assert_equal Prefab::EvaluationSummaryAggregator,
                 new_client(api_key: fake_api_key,
                            prefab_datasources: :all,
                            collect_evaluation_summaries: true).evaluation_summary_aggregator.class

    assert_logged [
      "WARN  2023-08-09 15:18:12 -0400: cloud.prefab.client No success loading checkpoints"
    ]
  end

  def test_get_with_basic_value
    config = basic_value_config
    client = new_client(config: config, project_env_id: PROJECT_ENV_ID, collect_evaluation_summaries: true,
                        context_upload_mode: :periodic_example, allow_telemetry_in_local_mode: true)

    assert_equal DESIRED_VALUE, client.get(config.key, IRRELEVANT, 'user' => { 'key' => 99 })

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

    assert_example_contexts client, [Prefab::Context.new({ user: { 'key' => 99 } })]
  end

  def test_get_with_basic_value_with_context
    config = basic_value_config
    client = new_client(config: config, project_env_id: PROJECT_ENV_ID, collect_evaluation_summaries: true,
                        context_upload_mode: :periodic_example, allow_telemetry_in_local_mode: true)

    client.with_context('user' => { 'key' => 99 }) do
      assert_equal DESIRED_VALUE, client.get(config.key)
    end

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

    assert_example_contexts client, [Prefab::Context.new({ user: { 'key' => 99 } })]
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

    client = new_client(config: config, project_env_id: PROJECT_ENV_ID, collect_evaluation_summaries: true,
                       context_upload_mode: :periodic_example, allow_telemetry_in_local_mode: true)

    2.times do
      assert_equal 'abc', client.get(config.key, IRRELEVANT, 'user' => { 'key' => '1' })
    end

    3.times do
      assert_equal 'def', client.get(config.key, IRRELEVANT, 'user' => { 'key' => '12' })
    end

    assert_equal 'ghi',
                 client.get(config.key, IRRELEVANT, 'user' => { 'key' => '4', admin: true })

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

    assert_example_contexts client, [
      Prefab::Context.new(user: { 'key' => '1' }),
      Prefab::Context.new(user: { 'key' => '12' }),
      Prefab::Context.new(user: { 'key' => '4', admin: true })
    ]
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
                        collect_evaluation_summaries: true, context_upload_mode: :periodic_example, allow_telemetry_in_local_mode: true)

    assert_equal DEFAULT_VALUE, client.get(config.key)
    assert_equal DEFAULT_VALUE,
                 client.get(config.key, IRRELEVANT, user: { key: 'abc', email: 'example@prefab.cloud' })
    assert_equal DESIRED_VALUE, client.get(config.key, IRRELEVANT, user: { key: 'def', email: 'example@hotmail.com' })

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

    assert_example_contexts client, [
      Prefab::Context.new(user: { key: 'abc', email: 'example@prefab.cloud' }),
      Prefab::Context.new(user: { key: 'def', email: 'example@hotmail.com' })
    ]
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
                        collect_evaluation_summaries: true, allow_telemetry_in_local_mode: true)

    assert_equal :DEBUG, client.get(config.key, IRRELEVANT)

    # nothing is summarized for log levels
    assert_summary client, {}
  end

  private

  def basic_value_config
    PrefabProto::Config.new(
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
  end
end
