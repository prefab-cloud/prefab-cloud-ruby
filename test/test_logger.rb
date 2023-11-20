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

      @logger.config_client = MockConfigClient.new({})
      assert_equal ::Logger::WARN,
                   @logger.level_of('app.models.user'), 'default is warn'

      @logger.config_client = MockConfigClient.new('log-level.app' => :INFO)
      assert_equal ::Logger::INFO,
                   @logger.level_of('app.models.user')

      @logger.config_client = MockConfigClient.new('log-level.app' => :DEBUG)
      assert_equal ::Logger::DEBUG,
                   @logger.level_of('app.models.user')

      @logger.config_client = MockConfigClient.new('log-level.app' => :DEBUG,
                                                   'log-level.app.models' => :ERROR)
      assert_equal ::Logger::ERROR,
                   @logger.level_of('app.models.user'), 'test leveling'
    end
  end

  def test_log_internal
    prefab, io = captured_logger
    prefab.log.log_internal(::Logger::WARN, 'test message', 'cloud.prefab.client.test.path')
    assert_logged io, 'WARN', "cloud.prefab.client.test.path", "test message"
  end

  def test_log_internal_unknown
    prefab, io = captured_logger
    prefab.log.log_internal(::Logger::UNKNOWN, 'test message', 'cloud.prefab.client.test.path')
    assert_logged io, 'ANY', "cloud.prefab.client.test.path", "test message"
  end

  def test_log_internal_silencing
    prefab, io = captured_logger
    prefab.log.silence do
      prefab.log.log_internal(::Logger::WARN, 'should not log', 'cloud.prefab.client.test.path')
    end
    prefab.log.log_internal(::Logger::WARN, 'should log', 'cloud.prefab.client.test.path')
    assert_logged io, 'WARN', "cloud.prefab.client.test.path", "should log"
    refute_logged io, 'should not log'
  end

  def test_log
    prefab, io = captured_logger
    prefab.log.log('test message', 'test.path', '', ::Logger::WARN)
    assert_logged io, 'WARN', "test.path", "test message"
  end

  def test_log_unknown
    prefab, io = captured_logger
    prefab.log.log('test message', 'test.path', '', ::Logger::UNKNOWN)
    assert_logged io, 'ANY', "test.path", "test message"
  end

  def test_log_silencing
    prefab, io = captured_logger
    prefab.log.silence do
      prefab.log.log('should not log', 'test.path', '', ::Logger::WARN)
    end
    prefab.log.log('should log', 'test.path', '', ::Logger::WARN)
    assert_logged io, 'WARN', "test.path", "should log"
    refute_logged io, 'should not log'
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

    assert_logged io, 'ERROR', 'MY_PROGNAME: test.test_logger.test_logging_with_a_progname', message
  end

  def test_logging_with_a_progname_and_no_message
    prefab, io = captured_logger

    prefab.log.progname = 'MY_PROGNAME'
    prefab.log.error

    assert_logged io, 'ERROR', 'MY_PROGNAME: test.test_logger.test_logging_with_a_progname_and_no_message', 'MY_PROGNAME'
  end

  def test_logging_with_criteria_on_top_level_key
    prefix = 'my.own.prefix'

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

    prefab, io = captured_logger(log_prefix: prefix)

    inject_config(prefab, config)
    inject_project_env_id(prefab, PROJECT_ENV_ID)

    # without any context, the level should be the default for the env (info)
    prefab.with_context({}) do
      prefab.log.debug 'Test debug'
      refute_logged io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'
    end

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.with_context(user: { email_suffix: 'yahoo.com' }) do
      prefab.log.debug 'Test debug'
      refute_logged io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'
    end

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.with_context(user: { email_suffix: 'hotmail.com' }) do
      prefab.log.debug 'Test debug'
      assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_top_level_key", 'Test error'
    end
  end

  def test_logging_with_criteria_on_key_path
    prefix = 'my.own.prefix'

    config = PrefabProto::Config.new(
      key: 'log-level.my.own.prefix.test.test_logger',
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

    prefab, io = captured_logger(log_prefix: prefix)

    inject_config(prefab, config)
    inject_project_env_id(prefab, PROJECT_ENV_ID)

    # without any context, the level should be the default for the env (info)
    prefab.with_context({}) do
      prefab.log.debug 'Test debug'
      refute_logged io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the wrong context, the level should be the default for the env (info)
    prefab.with_context(user: { email_suffix: 'yahoo.com' }) do
      prefab.log.debug 'Test debug'
      refute_logged io, 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the correct context, the level should be the desired value (debug)
    prefab.with_context(user: { email_suffix: 'hotmail.com' }) do
      prefab.log.debug 'Test debug'
      assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'
    end

    reset_io(io)

    # with the correct lookup key
    prefab.with_context(user: { tracking_id: 'user:4567' }) do
      prefab.log.debug 'Test debug'
      assert_logged io, 'DEBUG', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test debug'

      prefab.log.info 'Test info'
      assert_logged io, 'INFO', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test info'

      prefab.log.error 'Test error'
      assert_logged io, 'ERROR', "#{prefix}.test.test_logger.test_logging_with_criteria_on_key_path", 'Test error'
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

    assert_logged io, 'ERROR', 'test.test_logger.test_logging_with_a_block', message
  end

  def test_add_context_keys
    assert @logger.context_keys.empty?
    @logger.add_context_keys("user.name", "role.admin", "company.name")

    assert @logger.context_keys.to_a == %w(user.name role.admin company.name)
  end

  def test_context_keys_are_a_set
    @logger.add_context_keys("user.name", "role.admin", "company.name")

    assert @logger.context_keys.to_a == %w(user.name role.admin company.name)

    @logger.add_context_keys("user.name", "user.role")

    assert @logger.context_keys.to_a == %w(user.name role.admin company.name user.role)
  end

  def test_with_context_keys
    @logger.add_context_keys("company.name")

    assert @logger.context_keys.to_a == %w(company.name)

    @logger.with_context_keys("user.name", "role.admin") do
      assert @logger.context_keys.to_a == %w(company.name user.name role.admin)
    end

    assert @logger.context_keys.to_a == %w(company.name)
  end

  def test_structured_logging
    prefab, io = captured_logger
    message = 'HELLO'

    prefab.log.error message, user: "michael", id: 123

    assert_logged io, 'ERROR', 'test.test_logger.test_structured_logging', "#{message} id=123 user=michael"
  end

  def test_structured_json_logging
    prefab, io = captured_logger(log_formatter: Prefab::Options::JSON_LOG_FORMATTER)
    message = 'HELLO'

    prefab.log.error message, user: "michael", id: 123

    log_data = JSON.parse(io.string)
    assert log_data["message"] == message
    assert log_data["user"] == "michael"
    assert log_data["id"] == 123
  end

  def test_structured_internal_logging
    prefab, io = captured_logger

    prefab.log.log_internal(::Logger::WARN, 'test', 'cloud.prefab.client.test.path', user: "michael")

    assert_logged io, 'WARN', 'cloud.prefab.client.test.path', "test user=michael"
  end

  def test_structured_block_logger
    prefab, io = captured_logger
    message = 'MY MESSAGE'

    prefab.log.error user: "michael" do
      message
    end

    assert_logged io, 'ERROR', 'test.test_logger.test_structured_block_logger', "#{message} user=michael"
  end

  def test_structured_logger_with_context_keys
    prefab, io = captured_logger

    prefab.with_context({user: {name: "michael", job: "developer", admin: false}, company: { name: "Prefab" }}) do

      prefab.log.add_context_keys "user.name", "company.name", "user.admin"

      prefab.log.error "UH OH"

      assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys',
        "UH OH company.name=Prefab user.admin=false user.name=michael"
    end
  end

  def test_structured_logger_with_context_keys_ignores_nils
    prefab, io = captured_logger

    prefab.with_context({user: {name: "michael", job: "developer"}, company: { name: "Prefab" }}) do

      prefab.log.add_context_keys "user.name", "company.name", "user.admin"

      prefab.log.error "UH OH"

      assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys_ignores_nils',
        "UH OH company.name=Prefab user.name=michael"
    end
  end

  def test_structured_logger_with_context_keys_and_log_hash
    prefab, io = captured_logger

    prefab.with_context({user: {name: "michael", job: "developer", admin: false}, company: { name: "Prefab" }}) do

      prefab.log.add_context_keys "user.name", "company.name", "user.admin"

      prefab.log.error "UH OH", user_id: 6

      assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys_and_log_hash',
        "UH OH company.name=Prefab user.admin=false user.name=michael user_id=6"
    end

  end

  def test_structured_logger_with_context_keys_block
    prefab, io = captured_logger

    prefab.with_context({user: {name: "michael", job: "developer", admin: false}, company: { name: "Prefab" }}) do

      prefab.log.add_context_keys "user.name"

      prefab.log.error "UH OH"

      assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys_block',
        'UH OH user.name=michael'

      prefab.log.with_context_keys("company.name") do
        prefab.log.error "UH OH"

        assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys_block',
          'UH OH company.name=Prefab user.name=michael'
      end

      prefab.log.error "UH OH"

      assert_logged io, 'ERROR', 'test.test_logger.test_structured_logger_with_context_keys_block',
        'UH OH user.name=michael'
    end
  end

  def test_context_key_threads
    prefab, io = captured_logger

    threads = []
    1000.times.map do |i|
      threads << Thread.new do
        prefab.with_context({test: {"thread_#{i}": "thread_#{i}"}}) do
          prefab.log.add_context_keys "test.thread_#{i}"
          prefab.log.error "UH OH"
          assert_logged io, 'ERROR', 'test.test_logger.test_context_key_threads',
                        "UH OH test.thread_#{i}=thread_#{i}"
        end
      end
    end
    threads.each { |thr| thr.join }
  end

  private

  def assert_logged(logged_io, level, path, message)
    assert_match(/#{level}\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [-+]?\d+:\s+#{path} #{message}\n/, logged_io.string)
  end

  def refute_logged(logged_io, message)
    refute_match(/#{message}/, logged_io.string)
  end

  def captured_logger(options = {})
    io = StringIO.new
    options = Prefab::Options.new(**options.merge(
      logdev: io,
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
