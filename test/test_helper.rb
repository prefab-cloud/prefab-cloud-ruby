require 'minitest/autorun'
require 'prefab-cloud-ruby'

class MockBaseClient
  attr_reader :namespace, :logger, :environment

  def initialize(environment: "test", namespace: "")
    @environment = environment
    @namespace = namespace
    @logger = Logger.new($stdout)
    @config_values = {}
  end

  def account_id
    1
  end

  def log_internal level, message
  end

  def mock_this_config key, config_value
    @config_values[key] = config_value
  end

  def get(key)
    @config_values[key]
  end
end

class MockConfigLoader
  def calc_config
  end
end
