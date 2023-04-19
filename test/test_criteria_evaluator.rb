# frozen_string_literal: true

require 'test_helper'

class TestCriteriaEvaluator < Minitest::Test
  PROJECT_ENV_ID = 1
  TEST_ENV_ID = 2
  KEY = 'key'
  DEFAULT_VALUE = 'default_value'
  DESIRED_VALUE = 'desired_value'
  WRONG_ENV_VALUE = 'wrong_env_value'

  DEFAULT_ROW = Prefab::ConfigRow.new(
    values: [
      Prefab::ConditionalValue.new(
        value: Prefab::ConfigValue.new(string: DEFAULT_VALUE)
      )
    ]
  )

  def test_always_true
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(operator: Prefab::Criterion::CriterionOperator::ALWAYS_TRUE)
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
  end

  def test_nested_props_in
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[ok fine]),
                  property_name: 'user.key'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).string
  end

  def test_nested_props_not_in
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: string_list(%w[wrong bad]),
                  property_name: 'user.key'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context({ user: { key: 'ok' } })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({ user: { key: 'wrong' } })).string
  end

  def test_prop_is_one_of
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).string
  end

  def test_prop_is_not_one_of
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email_suffix: 'prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email_suffix: 'hotmail.com' })).string
  end

  def test_prop_ends_with_one_of
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string
  end

  def test_prop_does_not_end_with_one_of
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_DOES_NOT_END_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil,
                                                      namespace: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string
  end

  def test_in_seg
    segment_key = 'segment_key'

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,

        # wrong env
        Prefab::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key)
                )
              ],
              value: Prefab::ConfigValue.new(string: WRONG_ENV_VALUE)
            )
          ]
        ),

        # correct env
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key)
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string
  end

  def test_not_in_seg
    segment_key = 'segment_key'

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::NOT_IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key)
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil, namespace: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DESIRED_VALUE, evaluator.evaluate(context({})).string
    assert_equal DESIRED_VALUE, evaluator.evaluate(context(user: { email: 'example@prefab.cloud' })).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(user: { email: 'example@hotmail.com' })).string
  end

  def test_multiple_conditions_in_one_value
    segment_key = 'segment_key'

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                ),

                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: Prefab::ConfigValue.new(bool: true),
                  property_name: 'user.admin'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key)
                ),

                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: Prefab::ConfigValue.new(bool: true),
                  property_name: 'user.deleted'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil, namespace: nil,
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
  end

  def test_multiple_conditions_in_multiple_values
    segment_key = 'segment_key'

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: Prefab::ConfigValue.new(bool: true),
                  property_name: 'user.admin'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key)
                ),

                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_NOT_ONE_OF,
                  value_to_match: Prefab::ConfigValue.new(bool: true),
                  property_name: 'user.deleted'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil, namespace: nil,
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
  end

  def test_stringifying_property_values_and_names
    config = Prefab::Config.new(
      key: KEY,
      rows: [
        DEFAULT_ROW,
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[1 true hello]),
                  property_name: 'team.name'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil,
                                                      namespace: nil, base_client: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate(context({})).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate(context(team: { name: 'prefab.cloud' })).string

    [1, true, :hello].each do |value|
      [:name, 'name'].each do |property_name|
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value })).string
        assert_equal DESIRED_VALUE, evaluator.evaluate(context(team: { property_name => value.to_s })).string
      end
    end
  end

  private

  def string_list(values)
    Prefab::ConfigValue.new(string_list: Prefab::StringList.new(values: values))
  end

  class FakeResolver
    def initialize(config)
      @config = config
    end

    def raw(key)
      @config[key]
    end

    def get(key, properties = {})
      # This only gets called for segments, so we don't need to pass in a resolver
      Prefab::CriteriaEvaluator.new(@config[key], project_env_id: nil, resolver: nil,
                                                  namespace: nil, base_client: nil).evaluate(properties)
    end
  end

  def resolver_fake(config)
    FakeResolver.new(config)
  end

  def context(properties)
    Prefab::Context.new(properties)
  end
end
