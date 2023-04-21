# frozen_string_literal: true

require 'test_helper'

class TestConfigResolver < Minitest::Test
  STAGING_ENV_ID = 1
  PRODUCTION_ENV_ID = 2
  TEST_ENV_ID = 3
  SEGMENT_KEY = 'segment_key'
  CONFIG_KEY = 'config_key'
  DEFAULT_VALUE = 'default_value'
  IN_SEGMENT_VALUE = 'in_segment_value'
  WRONG_ENV_VALUE = 'wrong_env_value'
  NOT_IN_SEGMENT_VALUE = 'not_in_segment_value'

  def test_resolution
    @loader = MockConfigLoader.new

    loaded_values = {
      'key' => { config: Prefab::Config.new(
        key: 'key',
        rows: [
          Prefab::ConfigRow.new(
            values: [
              Prefab::ConditionalValue.new(
                value: Prefab::ConfigValue.new(string: 'value_no_env_default')
              )
            ]
          ),
          Prefab::ConfigRow.new(
            project_env_id: TEST_ENV_ID,
            values: [
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectB.subprojectX'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'projectB.subprojectX')
              ),
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectB.subprojectY'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'projectB.subprojectY')
              ),
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectA'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'valueA')
              ),
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectB'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'valueB')
              ),
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectB.subprojectX'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'projectB.subprojectX')
              ),
              Prefab::ConditionalValue.new(
                criteria: [
                  Prefab::Criterion.new(
                    operator: Prefab::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: Prefab::ConfigValue.new(string: 'projectB.subprojectY'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: Prefab::ConfigValue.new(string: 'projectB.subprojectY')
              ),
              Prefab::ConditionalValue.new(
                value: Prefab::ConfigValue.new(string: 'value_none')
              )
            ]
          )

        ]
      ) },
      'key2' => { config: Prefab::Config.new(
        key: 'key2',
        rows: [
          Prefab::ConfigRow.new(
            values: [
              Prefab::ConditionalValue.new(
                value: Prefab::ConfigValue.new(string: 'valueB2')
              )
            ]
          )
        ]
      ) }
    }

    @loader.stub :calc_config, loaded_values do
      @resolverA = resolver_for_namespace('', @loader, project_env_id: PRODUCTION_ENV_ID)
      assert_equal_context_and_jit 'value_no_env_default', @resolverA, 'key', {}, :string

      ## below here in the test env
      @resolverA = resolver_for_namespace('', @loader)
      assert_equal_context_and_jit 'value_none', @resolverA, 'key', {}, :string

      @resolverA = resolver_for_namespace('projectA', @loader)
      assert_equal_context_and_jit 'valueA', @resolverA, 'key', {}, :string

      @resolverB = resolver_for_namespace('projectB', @loader)
      assert_equal_context_and_jit 'valueB', @resolverB, 'key', {}, :string

      @resolverBX = resolver_for_namespace('projectB.subprojectX', @loader)
      assert_equal_context_and_jit 'projectB.subprojectX', @resolverBX, 'key', {}, :string

      @resolverBX = resolver_for_namespace('projectB.subprojectX', @loader)
      assert_equal_context_and_jit 'valueB2', @resolverBX, 'key2', {}, :string

      @resolverUndefinedSubProject = resolver_for_namespace('projectB.subprojectX.subsubQ', @loader)
      assert_equal_context_and_jit 'projectB.subprojectX', @resolverUndefinedSubProject, 'key', {}, :string

      @resolverBX = resolver_for_namespace('projectC', @loader)
      assert_equal_context_and_jit 'value_none', @resolverBX, 'key', {}, :string

      assert_nil @resolverBX.get('key_that_doesnt_exist', nil)
    end
  end

  def test_resolving_in_segment
    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: SEGMENT_KEY,
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
            Prefab::ConditionalValue.new(value: Prefab::ConfigValue.new(bool: false))
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: CONFIG_KEY,
      rows: [
        # wrong env
        Prefab::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: Prefab::ConfigValue.new(string: WRONG_ENV_VALUE)
            ),
            Prefab::ConditionalValue.new(
              criteria: [],
              value: Prefab::ConfigValue.new(string: DEFAULT_VALUE)
            )
          ]
        ),

        # correct env
        Prefab::ConfigRow.new(
          project_env_id: PRODUCTION_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: Prefab::ConfigValue.new(string: IN_SEGMENT_VALUE)
            ),
            Prefab::ConditionalValue.new(
              criteria: [],
              value: Prefab::ConfigValue.new(string: DEFAULT_VALUE)
            )
          ]
        )
      ]
    )

    loaded_values = {
      SEGMENT_KEY => { config: segment_config },
      CONFIG_KEY => { config: config }
    }

    loader = MockConfigLoader.new

    loader.stub :calc_config, loaded_values do
      options = Prefab::Options.new
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new(options), loader)
      resolver.project_env_id = PRODUCTION_ENV_ID

      assert_equal_context_and_jit DEFAULT_VALUE, resolver, CONFIG_KEY,
                                   { user: { email: 'test@something-else.com' } }, :string
      assert_equal_context_and_jit IN_SEGMENT_VALUE, resolver, CONFIG_KEY,
                                   { user: { email: 'test@hotmail.com' } }, :string
    end
  end

  def test_resolving_not_in_segment
    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: SEGMENT_KEY,
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
            Prefab::ConditionalValue.new(value: Prefab::ConfigValue.new(bool: false))
          ]
        )
      ]
    )

    config = Prefab::Config.new(
      key: CONFIG_KEY,
      rows: [
        Prefab::ConfigRow.new(
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: Prefab::ConfigValue.new(string: IN_SEGMENT_VALUE)
            ),
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::NOT_IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: Prefab::ConfigValue.new(string: NOT_IN_SEGMENT_VALUE)
            )
          ]
        )
      ]
    )

    loaded_values = {
      SEGMENT_KEY => { config: segment_config },
      CONFIG_KEY => { config: config }
    }

    loader = MockConfigLoader.new

    loader.stub :calc_config, loaded_values do
      options = Prefab::Options.new
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new(options), loader)

      assert_equal_context_and_jit IN_SEGMENT_VALUE, resolver, CONFIG_KEY, { user: { email: 'test@hotmail.com' } },
                                   :string
      assert_equal_context_and_jit NOT_IN_SEGMENT_VALUE, resolver, CONFIG_KEY, { user: { email: 'test@something-else.com' } },
                                   :string
    end
  end

  private

  def resolver_for_namespace(namespace, loader, project_env_id: TEST_ENV_ID)
    options = Prefab::Options.new(
      namespace: namespace
    )
    resolver = Prefab::ConfigResolver.new(MockBaseClient.new(options), loader)
    resolver.project_env_id = project_env_id
    resolver.update
    resolver
  end

  def assert_equal_context_and_jit(expected_value, resolver, key, properties, type)
    assert_equal expected_value, resolver.get(key, properties).send(type)

    Prefab::Context.with_context(properties) do
      assert_equal expected_value, resolver.get(key).send(type)
    end
  end
end
