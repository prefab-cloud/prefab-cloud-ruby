# frozen_string_literal: true

require 'test_helper'

class TestLogger < Minitest::Test
  TEST_ENV_ID = 2
  DEFAULT_VALUE = 'FATAL'
  DEFAULT_ENV_VALUE = 'INFO'
  DESIRED_VALUE = 'DEBUG'
  WRONG_ENV_VALUE = 'ERROR'
  PROJECT_ENV_ID = 1

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(
        value: PrefabProto::ConfigValue.new(log_level: DEFAULT_VALUE)
      )
    ]
  )

  def setup
    super
    Prefab::LoggerClient.send(:public, :class_path_name)
    Prefab::LoggerClient.send(:public, :level_of)
    @client = new_client
    @logger = @client.log
  end

  def test_bootstrap_log_level
    assert !Prefab.bootstrap_log_level(SemanticLogger::Log.new("TestLogger",:info))
    with_env('PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL', 'info') do
      assert Prefab.bootstrap_log_level(SemanticLogger::Log.new("TestLogger",:info))
    end
  end

  def test_level_of
    @logger.config_client = MockConfigClient.new({})
    assert_equal SemanticLogger::Levels.index(:warn),
                 @logger.level_of('app.models.user'), 'default is warn'

    @logger.config_client = MockConfigClient.new('log-level.app' => :INFO)
    assert_equal SemanticLogger::Levels.index(:info),
                 @logger.level_of('app.models.user')

    @logger.config_client = MockConfigClient.new('log-level.app' => :DEBUG)
    assert_equal SemanticLogger::Levels.index(:debug),
                 @logger.level_of('app.models.user')

    @logger.config_client = MockConfigClient.new('log-level.app' => :DEBUG,
                                                 'log-level.app.models' => :ERROR)
    assert_equal SemanticLogger::Levels.index(:error),
                 @logger.level_of('app.models.user'), 'test leveling'

  end


  def test_logging_with_criteria_on_top_level_key

    config = PrefabProto::Config.new(
      key: 'log-level',
      rows: [
        DEFAULT_ROW,

        # wrong env
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(log_level: WRONG_ENV_VALUE)
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(log_level: DESIRED_VALUE)
            ),
            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(log_level: DEFAULT_ENV_VALUE)
            )
          ]
        )
      ]
    )

    inject_config(@client, config)
    inject_project_env_id(@client, PROJECT_ENV_ID)

    # without any context, the level should be the default for the env (info)
    @client.with_context({}) do
      refute @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end


    # with the wrong context, the level should be the default for the env (info)
    @client.with_context(user: { email_suffix: 'yahoo.com' }) do
      refute @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end

    # with the correct context, the level should be the desired value (debug)
    @client.with_context(user: { email_suffix: 'hotmail.com' }) do
      assert @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end
  end

  def test_logging_with_criteria_on_key_path

    config = PrefabProto::Config.new(
      key: 'log-level.test.test_logger',
      rows: [
        DEFAULT_ROW,

        # wrong env
        PrefabProto::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(log_level: WRONG_ENV_VALUE)
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
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email_suffix'
                )
              ],
              value: PrefabProto::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            PrefabProto::ConditionalValue.new(
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[user:4567]),
                  property_name: 'user.tracking_id'
                )
              ],
              value: PrefabProto::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            PrefabProto::ConditionalValue.new(
              value: PrefabProto::ConfigValue.new(log_level: DEFAULT_ENV_VALUE)
            )
          ]
        )
      ]
    )
    inject_config(@client, config)
    inject_project_env_id(@client, PROJECT_ENV_ID)


    # without any context, the level should be the default for the env (info)
    @client.with_context({ }) do
      refute @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end

    # with the wrong context, the level should be the default for the env (info)
    @client.with_context(user: { email_suffix: 'yahoo.com' }) do
      refute @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end

    # with the correct context, the level should be the desired value (debug)
    @client.with_context(user: { email_suffix: 'hotmail.com' }) do
      assert @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:error), "test.test_logger" )
    end

    # with the correct lookup key
    @client.with_context(user: { tracking_id: 'user:4567' }) do
      assert @logger.should_log?(SemanticLogger::Levels.index(:debug), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
      assert @logger.should_log?(SemanticLogger::Levels.index(:info), "test.test_logger" )
    end
  end

  def test_class_path_name
    assert_equal "minitest.test.test_logger", @logger.class_path_name("TestLogger")
    assert_equal "prefab.logger_client", @logger.class_path_name("Prefab::LoggerClient")
    assert_equal "semantic_logger.logger.prefab.internal_logger", @logger.class_path_name("Prefab::InternalLogger")
  end

end
