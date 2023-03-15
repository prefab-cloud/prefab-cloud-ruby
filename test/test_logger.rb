# frozen_string_literal: true

require 'test_helper'

class TestLogger < Minitest::Test
  TEST_ENV_ID = 2
  DEFAULT_VALUE = 'FATAL'
  DEFAULT_ENV_VALUE = 'INFO'
  DESIRED_VALUE = 'DEBUG'
  WRONG_ENV_VALUE = 'ERROR'
  PROJECT_ENV_ID = 1

  DEFAULT_ROW = Prefab::ConfigRow.new(
    values: [
      Prefab::ConditionalValue.new(
        value: Prefab::ConfigValue.new(log_level: DEFAULT_VALUE)
      )
    ]
  )

  def setup
    Prefab::LoggerClient.send(:public, :get_path)
    Prefab::LoggerClient.send(:public, :get_loc_path)
    Prefab::LoggerClient.send(:public, :level_of)
    @logger = Prefab::LoggerClient.new($stdout)
  end

  def test_get_path
    assert_equal 'test_l.foo_warn',
                 @logger.get_path('/Users/jdwyah/Documents/workspace/RateLimitInc/prefab-cloud-ruby/lib/test_l.rb',
                                  'foo_warn')

    assert_equal 'active_support.log_subscriber.info',
                 @logger.get_path('/Users/jdwyah/.rvm/gems/ruby-2.3.3@forcerank/gems/activesupport-4.1.16/lib/active_support/log_subscriber.rb',
                                  'info')
    assert_equal 'active_support.log_subscriber.info',
                 @logger.get_path("/Users/jeffdwyer/.asdf/installs/ruby/3.1.2/lib/ruby/gems/3.1.0/gems/activesupport-7.0.2.4/lib/active_support/log_subscriber.rb:130:in `info'",
                                  'info')
    assert_equal 'unknown.info',
                 @logger.get_path(nil,
                                  'info')
  end

  def test_loc_resolution
    backtrace_location = Struct.new(:absolute_path, :base_label, :string) do
      def to_s
        string
      end
    end # https://ruby-doc.org/core-3.0.0/Thread/Backtrace/Location.html

    # verify that even if the Thread::Backtrace::Location does not have an absolute_location, we do our best
    assert_equal 'active_support.log_subscriber.info',
                 @logger.get_loc_path(backtrace_location.new(nil,
                                                             'info',
                                                             "/Users/jeffdwyer/.asdf/installs/ruby/3.1.2/lib/ruby/gems/3.1.0/gems/activesupport-7.0.2.4/lib/active_support/log_subscriber.rb:130:in `info'"))
    assert_equal 'test_l.info',
                 @logger.get_loc_path(backtrace_location.new('/Users/jdwyah/Documents/workspace/RateLimitInc/prefab-cloud-ruby/lib/test_l.rb',
                                                             'info',
                                                             "/Users/jeffdwyer/.asdf/installs/ruby/3.1.2/lib/ruby/gems/3.1.0/gems/activesupport-7.0.2.4/lib/active_support/log_subscriber.rb:130:in `info'"))
  end

  def test_level_of
    with_env('PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL', 'info') do
      # env var overrides the default level
      assert_equal ::Logger::INFO,
                   @logger.level_of('app.models.user'), 'PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL is info'

      @logger.set_config_client(MockConfigClient.new({}))
      assert_equal ::Logger::WARN,
                   @logger.level_of('app.models.user'), 'default is warn'

      @logger.set_config_client(MockConfigClient.new('log-level.app' => :INFO))
      assert_equal ::Logger::INFO,
                   @logger.level_of('app.models.user')

      @logger.set_config_client(MockConfigClient.new('log-level.app' => :DEBUG))
      assert_equal ::Logger::DEBUG,
                   @logger.level_of('app.models.user')

      @logger.set_config_client(MockConfigClient.new('log-level.app' => :DEBUG,
                                                     'log-level.app.models' => :ERROR))
      assert_equal ::Logger::ERROR,
                   @logger.level_of('app.models.user'), 'test leveling'
    end
  end

  def test_log_internal
    logger, mock_logdev = mock_logger_expecting(/W, \[.*\]  WARN -- cloud.prefab.client.test.path: : test message/)
    logger.log_internal('test message', 'test.path', '', ::Logger::WARN)
    mock_logdev.verify
  end

  def test_log_internal_unknown
    logger, mock_logdev = mock_logger_expecting(/A, \[.*\]   ANY -- cloud.prefab.client.test.path: : test message/)
    logger.log_internal('test message', 'test.path', '', ::Logger::UNKNOWN)
    mock_logdev.verify
  end

  def test_log_internal_silencing
    logger, mock_logdev = mock_logger_expecting(/W, \[.*\]  WARN -- cloud.prefab.client.test.path: : should log/,
                                                calls: 2)
    logger.silence do
      logger.log_internal('should not log', 'test.path', '', ::Logger::WARN)
    end
    logger.log_internal('should log', 'test.path', '', ::Logger::WARN)
    mock_logdev.verify
  end

  def test_log
    logger, mock_logdev = mock_logger_expecting(/W, \[.*\]  WARN -- test.path: : test message/)
    logger.log('test message', 'test.path', '', ::Logger::WARN)
    mock_logdev.verify
  end

  def test_log_unknown
    logger, mock_logdev = mock_logger_expecting(/A, \[.*\]   ANY -- test.path: : test message/)
    logger.log('test message', 'test.path', '', ::Logger::UNKNOWN)
    mock_logdev.verify
  end

  def test_log_silencing
    logger, mock_logdev = mock_logger_expecting(/W, \[.*\]  WARN -- test.path: : should log/, calls: 2)
    logger.silence do
      logger.log('should not log', 'test.path', '', ::Logger::WARN)
    end
    logger.log('should log', 'test.path', '', ::Logger::WARN)
    mock_logdev.verify
  end

  def test_logging_with_prefix
    prefix = 'my.own.prefix'
    message = 'this is a test'

    prefab, io = captured_logger(log_prefix: prefix)

    prefixed_logger = prefab.log
    prefixed_logger.error message

    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_prefix", message
  end

  def test_logging_without_a_progname
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.error message

    assert_logged io, 'ERROR', 'test.test_logger.test_logging_without_a_progname', message
  end

  def test_logging_without_a_progname_or_message
    prefab, io = captured_logger

    prefab.log.error

    assert_logged io, 'ERROR', 'test.test_logger.test_logging_without_a_progname_or_message', ''
  end

  def test_logging_with_a_progname
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.progname = 'MY_PROGNAME'
    prefab.log.error message

    assert_logged io, 'ERROR', 'MY_PROGNAME test.test_logger.test_logging_with_a_progname', message
  end

  def test_logging_with_a_progname_and_no_message
    prefab, io = captured_logger

    prefab.log.progname = 'MY_PROGNAME'
    prefab.log.error

    assert_logged io, 'ERROR', 'MY_PROGNAME test.test_logger.test_logging_with_a_progname_and_no_message', 'MY_PROGNAME'
  end

  def test_logging_with_criteria_on_top_level_key
    prefix = 'my.own.prefix'

    config = Prefab::Config.new(
      key: 'log-level',
      rows: [
        DEFAULT_ROW,

        # wrong env
        Prefab::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: WRONG_ENV_VALUE)
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
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: DESIRED_VALUE)
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(log_level: DEFAULT_ENV_VALUE)
            )
          ]
        )
      ]
    )

    prefab, io = captured_logger(log_prefix: prefix)

    inject_config(prefab, config)
    inject_project_env_id(prefab, PROJECT_ENV_ID)

    # without any context, the level should be the default for the env (info)
    prefab.set_thread_log_context(nil, {})

    prefab.log.debug 'Test debug'
    refute_logged io, 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.set_thread_log_context('user:1234', email_suffix: 'yahoo.com')

    prefab.log.debug 'Test debug'
    refute_logged io, 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.set_thread_log_context('user:1234', email_suffix: 'hotmail.com')

    prefab.log.debug 'Test debug'
    assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'
  end

  def test_logging_with_criteria_on_key_path
    prefix = 'my.own.prefix'

    config = Prefab::Config.new(
      key: 'log-level.my.own.prefix.test.test_logger',
      rows: [
        DEFAULT_ROW,

        # wrong env
        Prefab::ConfigRow.new(
          project_env_id: TEST_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: WRONG_ENV_VALUE)
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
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::LOOKUP_KEY_IN,
                  value_to_match: string_list(%w[user:4567]),
                  property_name: Prefab::CriteriaEvaluator::LOOKUP_KEY
                )
              ],
              value: Prefab::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(log_level: DEFAULT_ENV_VALUE)
            )
          ]
        )
      ]
    )

    prefab, io = captured_logger(log_prefix: prefix)

    inject_config(prefab, config)
    inject_project_env_id(prefab, PROJECT_ENV_ID)

    # without any context, the level should be the default for the env (info)
    prefab.set_thread_log_context(nil, {})

    prefab.log.debug 'Test debug'
    refute_logged io, 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.set_thread_log_context('user:1234', email_suffix: 'yahoo.com')

    prefab.log.debug 'Test debug'
    refute_logged io, 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.set_thread_log_context('user:1234', email_suffix: 'hotmail.com')

    prefab.log.debug 'Test debug'
    assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'

    reset_io(io)

    # with the correct lookup key
    prefab.set_thread_log_context('user:4567', email_suffix: 'example.com')

    prefab.log.debug 'Test debug'
    assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test debug'

    prefab.log.info 'Test info'
    assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

    prefab.log.error 'Test error'
    assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'
  end

  private

  def assert_logged(logged_io, level, path, message)
    assert_match(/#{level}\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [-+]?\d+:\s+#{path}: #{message}\n/, logged_io.string)
  end

  def refute_logged(logged_io, message)
    refute_match(/#{message}/, logged_io.string)
  end

  def mock_logger_expecting(pattern, configs = {}, calls: 1)
    mock_logdev = Minitest::Mock.new
    mock_logdev.expect :write, nil do |arg|
      pattern.match(arg)
    end

    calls.times.each do
      mock_logdev.expect(:nil?, false)
    end

    logger = Prefab::LoggerClient.new($stdout)
    logger.instance_variable_set('@logdev', mock_logdev)
    logger.set_config_client(MockConfigClient.new(configs))
    [logger, mock_logdev]
  end

  def captured_logger(options = {})
    io = StringIO.new
    options = Prefab::Options.new(**options.merge(
      logdev: io,
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    ))
    prefab = Prefab::Client.new(options)

    prefab.set_thread_log_context('NO_LOOKUP_KEY_SET', no_properties_set: true)

    [prefab, io]
  end

  def reset_io(io)
    io.close
    io.reopen

    assert_equal '', io.string
  end
end
