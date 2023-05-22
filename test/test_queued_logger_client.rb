# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestQueuedLoggerClient < Minitest::Test
  # TODO: share test cases

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

  def test_log
    prefab, io = captured_logger
    prefab.log.log('test message', 'test.path', '', ::Logger::WARN)
    assert_logged prefab, io, 'WARN', "test.path", "test message"
  end

  def test_log_unknown
    prefab, io = captured_logger
    prefab.log.log('test message', 'test.path', '', ::Logger::UNKNOWN)
    assert_logged prefab, io, 'ANY', "test.path", "test message"
  end

  def test_log_silencing
    prefab, io = captured_logger
    prefab.log.silence do
      prefab.log.log('should not log', 'test.path', '', ::Logger::WARN)
    end
    prefab.log.log('should log', 'test.path', '', ::Logger::WARN)
    assert_logged prefab, io, 'WARN', "test.path", "should log"
    refute_logged prefab, io, 'should not log'
  end

  def test_logging_with_prefix
    prefix = 'my.own.prefix'
    message = 'this is a test'

    prefab, io = captured_logger(log_prefix: prefix)

    prefixed_logger = prefab.log
    prefixed_logger.error message

    assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_prefix", message
  end

  def test_logging_without_a_progname
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.error message

    assert_logged prefab, io, 'ERROR', 'test.test_queued_logger_client.test_logging_without_a_progname', message
  end

  def test_logging_without_a_progname_or_message
    prefab, io = captured_logger

    prefab.log.error

    assert_logged prefab, io, 'ERROR', 'test.test_queued_logger_client.test_logging_without_a_progname_or_message', ''
  end

  def test_logging_with_a_progname
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.progname = 'MY_PROGNAME'
    prefab.log.error message

    assert_logged prefab, io, 'ERROR', 'MY_PROGNAME: test.test_queued_logger_client.test_logging_with_a_progname', message
  end

  def test_logging_with_a_progname_and_no_message
    prefab, io = captured_logger

    prefab.log.progname = 'MY_PROGNAME'
    prefab.log.error

    assert_logged prefab, io, 'ERROR', 'MY_PROGNAME: test.test_queued_logger_client.test_logging_with_a_progname_and_no_message', 'MY_PROGNAME'
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
                  property_name: 'user.email_suffix'
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
                  property_name: 'user.email_suffix'
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
    prefab.with_context({}) do
      prefab.log.debug 'Test debug'
      refute_logged prefab, io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test error'
    end

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.with_context(user: { email_suffix: 'yahoo.com' }) do
      prefab.log.debug 'Test debug'
      refute_logged prefab, io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test error'
    end

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.with_context(user: { email_suffix: 'hotmail.com' }) do
      prefab.log.debug 'Test debug'
      assert_logged prefab, io, 'DEBUG', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_top_level_key", 'Test error'
    end
  end

  def test_logging_with_criteria_on_key_path
    prefix = 'my.own.prefix'

    config = Prefab::Config.new(
      key: 'log-level.my.own.prefix.test.test_queued_logger_client',
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
                  property_name: 'user.email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[user:4567]),
                  property_name: 'user.tracking_id'
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
    prefab.with_context({}) do
      prefab.log.debug 'Test debug'
      refute_logged prefab, io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.with_context(user: { email_suffix: 'yahoo.com' }) do
      prefab.log.debug 'Test debug'
      refute_logged prefab, io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.with_context(user: { email_suffix: 'hotmail.com' }) do
      prefab.log.debug 'Test debug'
      assert_logged prefab, io, 'DEBUG', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the correct lookup key
    prefab.with_context(user: { tracking_id: 'user:4567' }) do
      prefab.log.debug 'Test debug'
      assert_logged prefab, io, 'DEBUG', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_logging_with_criteria_on_key_path", 'Test error'
    end
  end

  def test_logging_with_a_block
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.error do
      message
    end

    prefab.log.info do
      raise 'THIS WILL NEVER BE EVALUATED'
    end

    assert_logged prefab, io, 'ERROR', 'test.test_queued_logger_client.test_logging_with_a_block', message
  end

  def test_it_uses_the_time_at_logging_not_eval
    prefab, io = captured_logger

    log_time = Date.today - 30
    eval_time = Date.today

    Timecop.freeze(log_time) do
      prefab.log.log('past message', 'test.path', '', ::Logger::WARN)
    end

    Timecop.freeze(eval_time) do
      assert_logged prefab, io, 'WARN', "test.path", "past message"
    end

    assert_match log_time.to_s, io.string
    refute_match eval_time.to_s, io.string
  end

  def test_it_uses_the_context_at_logging_not_eval
    prefix = 'my.own.prefix'

    config = Prefab::Config.new(
      key: 'log-level.my.own.prefix.test.test_queued_logger_client',
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
                  property_name: 'user.email_suffix'
                )
              ],
              value: Prefab::ConfigValue.new(log_level: DESIRED_VALUE)
            ),

            Prefab::ConditionalValue.new(
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: string_list(%w[user:4567]),
                  property_name: 'user.tracking_id'
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

    prefab.with_context(user: { tracking_id: 'user:4567' }) do
      prefab.log.debug 'Test debug'
      prefab.log.info 'Test info'
      prefab.log.error 'Test error'
    end

    prefab.with_context({}) do
      assert_logged prefab, io, 'DEBUG', "#{prefix}.test.test_queued_logger_client.test_it_uses_the_context_at_logging_not_eval", 'Test debug'
      assert_logged prefab, io, 'INFO', "#{prefix}.test.test_queued_logger_client.test_it_uses_the_context_at_logging_not_eval", 'Test info'
      assert_logged prefab, io, 'ERROR', "#{prefix}.test.test_queued_logger_client.test_it_uses_the_context_at_logging_not_eval", 'Test error'
    end
  end

  def test_it_uses_the_silence_at_logging_not_eval
    prefab, io = captured_logger

    prefab.log.silence do
      prefab.log.log('should not log', 'test.path', '', ::Logger::WARN)
    end
    prefab.log.log('should log', 'test.path', '', ::Logger::WARN)

    prefab.log.silence do
      prefab.log.release
    end

    assert_logged prefab, io, 'WARN', "test.path", "should log"
    refute_logged prefab, io, 'should not log'
  end

  def test_it_can_use_a_provided_trace_id
    prefab, io = captured_logger
    prefab.log.set_trace_id('my-trace-id')

    prefab.log.log('test message', 'test.path', '', ::Logger::WARN)

    assert_equal 'my-trace-id', prefab.log.trace_id
    assert_equal ['my-trace-id'], prefab.log.instance_variable_get(:@trace_lookup).keys

    assert_logged prefab, io, 'WARN', "test.path", "test message"
  end

  private

  def assert_logged(prefab, logged_io, level, path, message)
    prefab.log.release

    assert_match(/#{level}\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [-+]?\d+:\s+#{path} #{message}\n/, logged_io.string)
  end

  def refute_logged(prefab, logged_io, message)
    prefab.log.release

    refute_match(/#{message}/, logged_io.string)
  end

  def captured_logger(options = {})
    io = StringIO.new
    options = Prefab::Options.new(**options.merge(
      logdev: io,
      logger_class: Prefab::QueuedLoggerClient,
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    ))
    prefab = Prefab::Client.new(options)

    [prefab, io]
  end

  def reset_io(io)
    io.close
    io.reopen

    assert_equal '', io.string
  end
end
