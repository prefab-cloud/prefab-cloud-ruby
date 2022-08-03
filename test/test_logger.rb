require 'test_helper'

class TestCLogger < Minitest::Test
  def setup
    Prefab::LoggerClient.send(:public, :get_path)
    Prefab::LoggerClient.send(:public, :level_of)
    @logger = Prefab::LoggerClient.new($stdout)
  end

  def test_get_path
    assert_equal "test_l.foo_warn",
                 @logger.get_path("/Users/jdwyah/Documents/workspace/RateLimitInc/prefab-cloud-ruby/lib/test_l.rb",
                                  "foo_warn")

    assert_equal "active_support.log_subscriber.info",
                 @logger.get_path("/Users/jdwyah/.rvm/gems/ruby-2.3.3@forcerank/gems/activesupport-4.1.16/lib/active_support/log_subscriber.rb",
                                  "info")
  end

  def test_level_of
    with_env("PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL", "info") do
      # env var overrides the default level
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
end
