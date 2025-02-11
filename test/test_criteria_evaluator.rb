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
    super
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client, namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        ),
        DEFAULT_ROW
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).unwrapped_value
  end

  def test_prop_starts_with_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_STARTS_WITH_ONE_OF,
                  value_to_match: string_list(['one', 'two']),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'three dogs' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'one tree' })).unwrapped_value
  end

  def test_prop_does_not_start_with_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_DOES_NOT_START_WITH_ONE_OF,
                  value_to_match: string_list(['one', 'two']),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'three dogs' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'one tree' })).unwrapped_value
  end


  def test_prop_contains_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_CONTAINS_ONE_OF,
                  value_to_match: string_list(['one', 'two']),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'three dogs' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'see one tree' })).unwrapped_value
  end

  def test_prop_does_not_contain_one_of
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_DOES_NOT_CONTAIN_ONE_OF,
                  value_to_match: string_list(['one', 'two']),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'three dogs' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'see one tree' })).unwrapped_value
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

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).unwrapped_value
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
                  operator: PrefabProto::Criterion::CriterionOperator::NOT_IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: segment_key)
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).unwrapped_value
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
              value: TRUE_CONFIG,
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: TRUE_CONFIG,
                  property_name: 'user.admin'
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
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: TRUE_CONFIG,
                  property_name: 'user.deleted'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true })).unwrapped_value
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true, deleted: true })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true })).unwrapped_value
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true, deleted: true })).unwrapped_value
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
              value: TRUE_CONFIG,
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(
              value: TRUE_CONFIG,
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: TRUE_CONFIG,
                  property_name: 'user.admin'
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
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: TRUE_CONFIG,
                  property_name: 'user.deleted'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: @base_client, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { admin: true })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true })).unwrapped_value
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@prefab.cloud', admin: true, deleted: true })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true })).unwrapped_value
    assert_equal DEFAULT_VALUE,
                 evaluator.evaluate(context(user: { email: 'example@gmail.com', admin: true, deleted: true })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil,
                                                      namespace: nil, base_client: @base_client)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(team: { name: 'prefab.cloud' })).unwrapped_value

    [1, true, :hello].each do |value|
      [:name, 'name'].each do |property_name|
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value })).unwrapped_value
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value.to_s })).unwrapped_value
      end
    end
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
              value: DESIRED_VALUE_CONFIG
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

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 32 } })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 29 } })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ 'user' => { 'age' => 41 } })).unwrapped_value
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
              value: DESIRED_VALUE_CONFIG
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
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    end

    Timecop.freeze(now - 60) do
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    end

    Timecop.freeze(now - 61) do
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    end

    Timecop.freeze(now + 59) do
      assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    end

    Timecop.freeze(now + 60) do
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    end
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

    assert_equal :DEBUG, evaluator.evaluate(context({})).unwrapped_value
  end

  def test_evaluating_a_weighted_value
    config = PrefabProto::Config.new(
      id: 123,
      key: KEY,
      config_type: PrefabProto::ConfigType::CONFIG,
      rows: [
        PrefabProto::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [PrefabProto::Criterion.new(operator: PrefabProto::Criterion::CriterionOperator::ALWAYS_TRUE)],
              value: PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 98], ['def', 1], ['ghi', 1]]))
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client, namespace: nil)

    2.times do
      assert_equal 'abc', evaluator.evaluate(context('user' => { 'key' => '1' })).unwrapped_value
    end

    3.times do
      context = context({ 'user' => { 'key' => '12' } })
      assert_equal 'def', evaluator.evaluate(context).unwrapped_value
    end

    context = context({ 'user' => { 'key' => '4' } })
    assert_equal 'ghi', evaluator.evaluate(context).unwrapped_value
  end

  def test_prop_regex_matches
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_MATCHES,
                  value_to_match: PrefabProto::ConfigValue.new(string: "a+b+"),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'abc' })).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'aabb' })).unwrapped_value
  end

  def test_prop_regex_does_not_match
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_DOES_NOT_MATCH,
                  value_to_match: PrefabProto::ConfigValue.new(string: "a+b+"),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).unwrapped_value
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { testProperty: 'abc' })).unwrapped_value
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'aabb' })).unwrapped_value
  end

  def test_prop_regex_does_not_match_returns_false_bad_regex
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_DOES_NOT_MATCH,
                  value_to_match: PrefabProto::ConfigValue.new(string: "[a+b+"),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)
    #silencing stderr because of "warning: character class has duplicated range: /^[a+b+$/"
    silence_stderr do
     assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
     assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'abc' })).unwrapped_value
    end
  end


  def test_prop_regex_match_returns_false_bad_regex
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_MATCHES,
                  value_to_match: PrefabProto::ConfigValue.new(string: "[a+b+"),
                  property_name: 'user.testProperty'
                )
              ],
              value: DESIRED_VALUE_CONFIG
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: @base_client,
                                              namespace: nil)
    #silencing stderr because of "warning: character class has duplicated range: /^[a+b+$/"

    silence_stderr do
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).unwrapped_value
      assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { testProperty: 'abc' })).unwrapped_value
    end

  end

  private

  def silence_stderr
    original_stderr = $stderr
    $stderr = File.open(File::NULL, "w")  # Redirect STDERR to null
    yield
  ensure
    $stderr = original_stderr  # Restore STDERR after execution
  end

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

  class FakeBaseClient
    def evaluation_summary_aggregator
      @evaluation_summary_aggregator ||= Prefab::EvaluationSummaryAggregator.new(client: self, max_keys: 9999, sync_interval: 9999)
    end

    def instance_hash
      'fake-base-client-instance_hash'
    end
  end
end
