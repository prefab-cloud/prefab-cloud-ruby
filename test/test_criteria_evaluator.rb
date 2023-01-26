# frozen_string_literal: true

require 'test_helper'

class TestCriteriaEvaluator < Minitest::Test
  PROJECT_ENV_ID = 1
  KEY = 'key'
  DEFAULT_VALUE = 'value_no_env_default'
  DESIRED_VALUE = 'desired_value'

  DEFAULT_ROW = Prefab::ConfigRow.new(
    values: [
      Prefab::ConditionalValue.new(
        value: Prefab::ConfigValue.new(string: DEFAULT_VALUE)
      )
    ]
  )

  def test_lookup_key_in
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
                  operator: Prefab::Criterion::CriterionOperator::LOOKUP_KEY_IN,
                  value_to_match: string_list(%w[ok fine]),
                  property_name: Prefab::CriteriaEvaluator::LOOKUP_KEY
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate({}).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ Prefab::CriteriaEvaluator::LOOKUP_KEY => 'wrong' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ Prefab::CriteriaEvaluator::LOOKUP_KEY => 'ok' }).string
  end

  def test_lookup_key_not_in
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
                  operator: Prefab::Criterion::CriterionOperator::LOOKUP_KEY_NOT_IN,
                  value_to_match: string_list(%w[wrong bad]),
                  property_name: Prefab::CriteriaEvaluator::LOOKUP_KEY
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate({}).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ Prefab::CriteriaEvaluator::LOOKUP_KEY => 'ok' }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ Prefab::CriteriaEvaluator::LOOKUP_KEY => 'wrong' }).string
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
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate({}).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email_suffix: 'prefab.cloud' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email_suffix: 'hotmail.com' }).string
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
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate({}).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email_suffix: 'prefab.cloud' }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email_suffix: 'hotmail.com' }).string
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
                  property_name: 'email'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DEFAULT_VALUE, evaluator.evaluate({}).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@hotmail.com' }).string
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
                  property_name: 'email'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID, resolver: nil, base_client: nil)

    assert_equal DESIRED_VALUE, evaluator.evaluate({}).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud' }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@hotmail.com' }).string
  end

  def test_in_seg
    segment_key = 'segment_key'

    segment = Prefab::Segment.new(criteria: [
                                    Prefab::Criterion.new(
                                      operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                                      value_to_match: string_list(['hotmail.com', 'gmail.com']),
                                      property_name: 'email'
                                    )
                                  ])

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(segment: segment)
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
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate({}).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@hotmail.com' }).string
  end

  def test_not_in_seg
    segment_key = 'segment_key'

    segment = Prefab::Segment.new(criteria: [
                                    Prefab::Criterion.new(
                                      operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                                      value_to_match: string_list(['hotmail.com', 'gmail.com']),
                                      property_name: 'email'
                                    )
                                  ])

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(segment: segment)
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
                                                      base_client: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DESIRED_VALUE, evaluator.evaluate({}).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud' }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@hotmail.com' }).string
  end

  def test_multiple_conditions
    segment_key = 'segment_key'

    segment = Prefab::Segment.new(criteria: [
                                    Prefab::Criterion.new(
                                      operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                                      value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                                      property_name: 'email'
                                    ),

                                    Prefab::Criterion.new(
                                      operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                                      value_to_match: Prefab::ConfigValue.new(bool: true),
                                      property_name: 'admin'
                                    )
                                  ])

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(segment: segment)
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
                  property_name: 'deleted'
                )
              ],
              value: Prefab::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    evaluator = Prefab::CriteriaEvaluator.new(config, project_env_id: PROJECT_ENV_ID,
                                                      base_client: nil,
                                                      resolver: resolver_fake({ segment_key => segment_config }))

    assert_equal DEFAULT_VALUE, evaluator.evaluate({}).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud', admin: true }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@prefab.cloud', admin: true, deleted: true }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@gmail.com' }).string
    assert_equal DESIRED_VALUE, evaluator.evaluate({ email: 'example@gmail.com', admin: true }).string
    assert_equal DEFAULT_VALUE, evaluator.evaluate({ email: 'example@gmail.com', admin: true, deleted: true }).string
  end

  private

  def string_list(values)
    Prefab::ConfigValue.new(string_list: Prefab::StringList.new(values: values))
  end

  class FakeResolver
    def initialize(segments)
      @segments = segments
    end

    def segment_criteria(key)
      segment = @segments[key]
      segment.rows[0].values[0].value.segment.criteria
    end
  end

  def resolver_fake(segments)
    FakeResolver.new(segments)
  end
end
