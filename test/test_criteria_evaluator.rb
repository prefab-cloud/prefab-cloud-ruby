# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestCriteriaEvaluator < Minitest::Test
  PROJECT_ENV_ID = 1
  TEST_ENV_ID = 2
  KEY = 'the-key'
  DEFAULT_VALUE = 'default_value'
  DESIRED_VALUE = 'desired_value'
  WRONG_ENV_VALUE = 'wrong_env_value'

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(
        value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
      )
    ]
  )

  def setup
    @base_client = FakeBaseClient.new
  end

  def test_always_true
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
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client, namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string

    assert_summary @base_client, {
      [KEY, :CONFIG] => {
        {
          config_id: config.id,
          config_row_index: 1,
          conditional_value_index: 0,
          weighted_value_index: nil,
          selected_index: nil
        } => 1
      }
    }
  end

  def test_nested_props_in
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[ok fine]),
                  property_name: 'user.key'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_nested_props_not_in
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: string_list(%w[wrong bad]),
                  property_name: 'user.key'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_prop_is_one_of
    config = PrefabProto::Config.new(
      key: KEY,
      rows: [
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        ),
        DEFAULT_ROW
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2
      }
    }
  end

  def test_prop_is_not_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_prop_ends_with_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_prop_does_not_end_with_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_DOES_NOT_END_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
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
              value: PrefabProto::ConfigValue.new(bool: true),
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    config = PrefabProto::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,

        # wrong env
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: segment_key)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: WRONG_ENV_VALUE)
            )
          ]
        ),

        # correct env
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
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string

    assert_summary @base_client, {
      [segment_key, :SEGMENT] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      },
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2, { config_id: 0, config_row_index: 2, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_not_in_seg
    segment_key = 'segment_key'

    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: true),
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: false)
            )
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
                  operator: PrefabProto::Criterion::CriterionOperator::NOT_IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: segment_key)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string

    assert_summary @base_client, {
      [segment_key, :SEGMENT] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      },
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_multiple_conditions_in_one_value
    segment_key = 'segment_key'

    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: true),
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: PrefabProto::ConfigValue.new(bool: true),
                  property_name: 'user.admin'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: false)
            )
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
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: PrefabProto::ConfigValue.new(bool: true),
                  property_name: 'user.deleted'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true })).string
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true, deleted: true })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true })).string
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true, deleted: true })).string

    assert_summary @base_client, {
      [segment_key, :SEGMENT] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 3,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 4
      },
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 5,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2
      }
    }
  end

  def test_multiple_conditions_in_multiple_values
    segment_key = 'segment_key'

    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: true),
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: true),
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: PrefabProto::ConfigValue.new(bool: true),
                  property_name: 'user.admin'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(bool: false)
            )
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
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: PrefabProto::ConfigValue.new(bool: true),
                  property_name: 'user.deleted'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { admin: true })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true })).string
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true, deleted: true })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true })).string
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true, deleted: true })).string

    assert_summary @base_client, {
      [segment_key, :SEGMENT] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 2, weighted_value_index: nil, selected_index: nil } => 1,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 6,
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 1
      },
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 3,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 5
      }
    }
  end

  def test_stringifying_property_values_and_names
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[1 true hello]),
                  property_name: 'team.name'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil,
                                                      namespace: nil, base_client: @base_client)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(team: { name: 'prefab.cloud' })).string

    [1, true, :hello].each do |value|
      [:name, 'name'].each do |property_name|
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value })).string
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value.to_s })).string
      end
    end

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 2,
        { config_id: 0, config_row_index: 1, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 12
      }
    }
  end

  def test_in_int_range
    config = PrefabProto::Config.new(
      key: KEY,
      rows: [
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::IN_INT_RANGE,
                                           value_to_match: PrefabProto::ConfigValue.new(int_range: PrefabProto::IntRange.new(start: 30, end: 40)), property_name: 'user.age')
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            ),

            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)
              ],
              value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil,
                                                      namespace: nil, base_client: @base_client)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 32 } })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 29 } })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 41 } })).string

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 3,
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 1
      }
    }
  end

  def test_in_int_range_for_time
    now = Time.now

    config = PrefabProto::Config.new(
      key: KEY,
      rows: [
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::IN_INT_RANGE,
                                           value_to_match: PrefabProto::ConfigValue.new(
                                             int_range: PrefabProto::IntRange.new(
                                               start: (now.to_i - 60) * 1000, end: (now.to_i + 60) * 1000
                                             )
                                           ), property_name: 'prefab.current-time')
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            ),

            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)
              ],
              value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil,
                                                      namespace: nil, base_client: @base_client)

    Timecop.freeze(now) do
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    end

    Timecop.freeze(now - 60) do
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    end

    Timecop.freeze(now - 61) do
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    end

    Timecop.freeze(now + 59) do
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    end

    Timecop.freeze(now + 60) do
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    end

    assert_summary @base_client, {
      [KEY, :NOT_SET_CONFIG_TYPE] => {
        { config_id: 0, config_row_index: 0, conditional_value_index: 0, weighted_value_index: nil, selected_index: nil } => 3,
        { config_id: 0, config_row_index: 0, conditional_value_index: 1, weighted_value_index: nil, selected_index: nil } => 2
      }
    }
  end

  def test_evaluating_a_log_level
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

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client, namespace: nil)

    assert_equal :DEBUG, evaluator.evaluate(context({})).log_level

    # These aren't summarized
    assert_summary @base_client, {}
  end

  private

  def string_list(values)
    PrefabProto::ConfigValue.new(string_list: PrefabProto::StringList.new(values: values))
  end

  class FakeResolver
    def initialize(config, base_client)
      @config = config
      @base_client = base_client
    end

    def raw(key)
      @config[key]
    end

    def get(key, properties = {})
      # This only gets called for segments, so we don't need to pass in a resolver
      Prefab::CriteriaEvaluator.new(@config[key], project_env_id: nil, resolver: nil,
                                                  namespace: nil, base_client: @base_client).evaluate(properties)
    end
  end

  def resolver_fake(config)
    FakeResolver.new(config, @base_client)
  end

  def context(properties)
    Prefab::Context.new(properties)
  end

  class FakeLogger
    def info(msg)
      # loudly complain about unexpected log messages
      raise msg
    end

    def log_internal(*args); end
  end

  class FakeBaseClient
    def log
      FakeLogger.new
    end

    def evaluation_summary_aggregator
      @evaluation_summary_aggregator ||= Prefab::EvaluationSummaryAggregator.new(client: self, max_keys: 9999, sync_interval: 9999)
    end

    def instance_hash
      'fake-base-client-instance_hash'
    end
  end
end
