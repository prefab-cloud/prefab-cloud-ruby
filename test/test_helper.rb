require 'minitest/autorun'
require 'prefab-cloud-ruby'

class MockBaseClient
  attr_reader :namespace, :logger, :environment

  def initialize(environment: "test", namespace: "")
    @environment = environment
    @namespace = namespace
    @logger = Logger.new($stdout)
  end

  def account_id
    1
  end

  def log_internal level, message
  end
end

class MockConfigLoader
  def calc_config
  end
end
