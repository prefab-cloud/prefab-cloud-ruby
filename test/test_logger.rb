require 'test_helper'

class TestCLogger < Minitest::Test
  def setup
    Prefab::LoggerClient.send(:public, :get_path)
    Prefab::LoggerClient.send(:public, :level_of)
    @logger = Prefab::LoggerClient.new($stdout)
  end

  def test_get_path
    assert_equal "lib.test_l.foo_warn",
                 @logger.get_path("/Users/jeffdwyer/Documents/workspace/RateLimitInc/prefab-cloud-ruby/lib/test_l.rb",
                                  "foo_warn")
  end

  def test_level_of
    assert_equal Logger::INFO,
                 @logger.level_of("app.models.user"), "PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL is info"

    @logger.set_config_client(MockConfigClient.new({}))
    assert_equal Logger::WARN,
                 @logger.level_of("app.models.user"), "default is warn"

    @logger.set_config_client(MockConfigClient.new("log_level.app" => "info"))
    assert_equal Logger::INFO,
                 @logger.level_of("app.models.user")

    @logger.set_config_client(MockConfigClient.new("log_level.app" => "debug"))
    assert_equal Logger::DEBUG,
                 @logger.level_of("app.models.user")

    @logger.set_config_client(MockConfigClient.new("log_level.app" => "debug",
                                                   "log_level.app.models" => "warn"))
    assert_equal Logger::WARN,
                 @logger.level_of("app.models.user")
  end
end

class MockConfigClient
  def initialize(hash)
    @hash = hash
  end

  def get(key)
    @hash[key]
  end
end
