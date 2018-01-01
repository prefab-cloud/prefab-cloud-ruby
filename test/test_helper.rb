require 'minitest/autorun'
require 'prefab-cloud-ruby'

class MockBaseClient
  attr_reader :namespace, :logger

  def initialize(namespace: "")
    @namespace = namespace
    @logger = Logger.new($stdout)
  end

  def account_id
    1
  end
end

class MockConfigLoader
  def calc_config

  end
end
