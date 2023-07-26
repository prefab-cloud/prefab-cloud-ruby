# frozen_string_literal: true

require 'test_helper'

class TestConfigResolver < Minitest::Test
  STAGING_ENV_ID = 1
  PRODUCTION_ENV_ID = 2
  TEST_ENV_ID = 3
  SEGMENT_KEY = 'segment_key'
  CONFIG_KEY = 'config_key'
  DEFAULT_VALUE = 'default_value'
  DESIRED_VALUE = 'desired_value'
  IN_SEGMENT_VALUE = 'in_segment_value'
  WRONG_ENV_VALUE = 'wrong_env_value'
  NOT_IN_SEGMENT_VALUE = 'not_in_segment_value'

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(
        value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
      )
    ]
  )

  def test_resolution
    @loader = MockConfigLoader.new

    loaded_values = {
      'key' => { config: PrefabProto::Config.new(
        key: 'key',
        rows: [
          DEFAULT_ROW,
          PrefabProto::ConfigRow.new(
            project_env_id: TEST_ENV_ID,
            values: [
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectB.subprojectX'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'projectB.subprojectX')
              ),
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectB.subprojectY'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'projectB.subprojectY')
              ),
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectA'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'valueA')
              ),
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectB'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'valueB')
              ),
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectB.subprojectX'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'projectB.subprojectX')
              ),
              PrefabProto::ConditionalValue.new(
                criteria: [
                  PrefabProto::Criterion.new(
                    operator: PrefabProto::Criterion::CriterionOperator::HIERARCHICAL_MATCH,
                    value_to_match: PrefabProto::ConfigValue.new(string: 'projectB.subprojectY'),
                    property_name: Prefab::CriteriaEvaluator::NAMESPACE_KEY
                  )
                ],
                value: PrefabProto::ConfigValue.new(string: 'projectB.subprojectY')
              ),
              PrefabProto::ConditionalValue.new(
                value: PrefabProto::ConfigValue.new(string: 'value_none')
              )
            ]
          )

        ]
      ) },
      'key2' => { config: PrefabProto::Config.new(
        key: 'key2',
        rows: [
          PrefabProto::ConfigRow.new(
            values: [
              PrefabProto::ConditionalValue.new(
                value: PrefabProto::ConfigValue.new(string: 'valueB2')
              )
            ]
          )
        ]
      ) }
    }

    @loader.stub :calc_config, loaded_values do
      @resolverA = resolver_for_namespace('', @loader, project_env_id: PRODUCTION_ENV_ID)
      assert_equal_context_and_jit DEFAULT_VALUE, @resolverA, 'key', {}

      ## below here in the test env
      @resolverA = resolver_for_namespace('', @loader)
      assert_equal_context_and_jit 'value_none', @resolverA, 'key', {}

      @resolverA = resolver_for_namespace('projectA', @loader)
      assert_equal_context_and_jit 'valueA', @resolverA, 'key', {}

      @resolverB = resolver_for_namespace('projectB', @loader)
      assert_equal_context_and_jit 'valueB', @resolverB, 'key', {}

      @resolverBX = resolver_for_namespace('projectB.subprojectX', @loader)
      assert_equal_context_and_jit 'projectB.subprojectX', @resolverBX, 'key', {}

      @resolverBX = resolver_for_namespace('projectB.subprojectX', @loader)
      assert_equal_context_and_jit 'valueB2', @resolverBX, 'key2', {}

      @resolverUndefinedSubProject = resolver_for_namespace('projectB.subprojectX.subsubQ',
                                                            @loader)
      assert_equal_context_and_jit 'projectB.subprojectX', @resolverUndefinedSubProject, 'key', {}

      @resolverBX = resolver_for_namespace('projectC', @loader)
      assert_equal_context_and_jit 'value_none', @resolverBX, 'key', {}

      assert_nil @resolverBX.get('key_that_doesnt_exist', nil)

      assert_equal @resolverBX.to_s.strip.split("\n").map(&:strip), [
        'key                                                | value_none                          | String  | Match:                         | Source:',
        'key2                                               | valueB2                             | String  | Match:                         | Source:'
      ]

      assert_equal @resolverBX.presenter.to_h, {
        'key' => Prefab::ResolvedConfigPresenter::ConfigRow.new('key', 'value_none', nil, nil),
        'key2' => Prefab::ResolvedConfigPresenter::ConfigRow.new('key2', 'valueB2', nil, nil)
      }

      resolved_lines = []
      @resolverBX.presenter.each do |key, row|
        resolved_lines << [key, row.value]
      end
      assert_equal resolved_lines, [%w[key value_none], %w[key2 valueB2]]
    end
  end

  def test_resolving_in_segment
    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: SEGMENT_KEY,
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
            PrefabProto::ConditionalValue.new(value: PrefabProto::ConfigValue.new(bool: false))
          ]
        )
      ]
    )

    config = PrefabProto::Config.new(
      key: CONFIG_KEY,
      rows: [
        # wrong env
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: WRONG_ENV_VALUE)
            ),
            PrefabProto::ConditionalValue.new(
              criteria: [],
              value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
            )
          ]
        ),

        # correct env
        PrefabProto::ConfigRow.new(
          project_env_id: PRODUCTION_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: IN_SEGMENT_VALUE)
            ),
            PrefabProto::ConditionalValue.new(
              criteria: [],
              value: PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
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
                                   { user: { email: 'test@something-else.com' } }
      assert_equal_context_and_jit IN_SEGMENT_VALUE, resolver, CONFIG_KEY,
                                   { user: { email: 'test@hotmail.com' } }
    end
  end

  def test_resolving_not_in_segment
    segment_config = PrefabProto::Config.new(
      config_type: PrefabProto::ConfigType::SEGMENT,
      key: SEGMENT_KEY,
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
            PrefabProto::ConditionalValue.new(value: PrefabProto::ConfigValue.new(bool: false))
          ]
        )
      ]
    )

    config = PrefabProto::Config.new(
      key: CONFIG_KEY,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: IN_SEGMENT_VALUE)
            ),
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::NOT_IN_SEG,
                  value_to_match: PrefabProto::ConfigValue.new(string: SEGMENT_KEY)
                )
              ],
              value: PrefabProto::ConfigValue.new(string: NOT_IN_SEGMENT_VALUE)
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

      assert_equal_context_and_jit IN_SEGMENT_VALUE, resolver, CONFIG_KEY, { user: { email: 'test@hotmail.com' } }
      assert_equal_context_and_jit NOT_IN_SEGMENT_VALUE, resolver, CONFIG_KEY, { user: { email: 'test@something-else.com' } }
    end
  end

  def test_jit_context_merges_with_existing_context
    config = PrefabProto::Config.new(
      key: CONFIG_KEY,
      rows: [
        DEFAULT_ROW,
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[pro advanced]),
                  property_name: 'team.plan'
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(%w[@example.com]),
                  property_name: 'user.email'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    loader = MockConfigLoader.new

    loader.stub :calc_config, { CONFIG_KEY => { config: config } } do
      options = Prefab::Options.new
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new(options), loader)
      resolver.project_env_id = TEST_ENV_ID

      Prefab::Context.with_context({ user: { email: 'test@example.com' } }) do
        assert_equal DEFAULT_VALUE, resolver.get(CONFIG_KEY).unwrapped_value
        assert_equal DEFAULT_VALUE, resolver.get(CONFIG_KEY, { team: { plan: 'freebie' } }).unwrapped_value
        assert_equal DESIRED_VALUE, resolver.get(CONFIG_KEY, { team: { plan: 'pro' } }).unwrapped_value
      end
    end
  end

  def test_jit_can_clobber_existing_context
    config = PrefabProto::Config.new(
      key: CONFIG_KEY,
      rows: [
        DEFAULT_ROW,
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[pro advanced]),
                  property_name: 'team.plan'
                ),

                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(%w[@example.com]),
                  property_name: 'user.email'
                )
              ],
              value: PrefabProto::ConfigValue.new(string: DESIRED_VALUE)
            )
          ]
        )
      ]
    )

    loader = MockConfigLoader.new

    loader.stub :calc_config, { CONFIG_KEY => { config: config } } do
      options = Prefab::Options.new
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new(options), loader)
      resolver.project_env_id = TEST_ENV_ID

      Prefab::Context.with_context({ user: { email: 'test@hotmail.com' }, team: { plan: 'pro' } }) do
        assert_equal DEFAULT_VALUE, resolver.get(CONFIG_KEY).unwrapped_value
        assert_equal DESIRED_VALUE, resolver.get(CONFIG_KEY, { user: { email: 'test@example.com' } }).unwrapped_value
        assert_equal DEFAULT_VALUE, resolver.get(CONFIG_KEY, { team: { plan: 'freebie' } }).unwrapped_value
      end
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

  def assert_equal_context_and_jit(expected_value, resolver, key, properties)
    assert_equal expected_value, resolver.get(key, properties).unwrapped_value

    Prefab::Context.with_context(properties) do
      assert_equal expected_value, resolver.get(key).unwrapped_value
    end
  end
end
