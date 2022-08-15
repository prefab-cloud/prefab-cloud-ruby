# frozen_string_literal: true
require 'minitest/autorun'
require 'prefab-cloud-ruby'

class MockBaseClient
  STAGING_ENV_ID = 1
  PRODUCTION_ENV_ID = 2
  TEST_ENV_ID = 3
  attr_reader :namespace, :logger, :config_client, :options

  def initialize(options = Prefab::Options.new)
    @options = options
    @namespace = namespace
    @logger = Prefab::LoggerClient.new($stdout)
    @config_client = MockConfigClient.new
  end

  def project_id
    1
  end

  def log
    @logger
  end

  def log_internal level, message
  end

  def config_value key
    @config_values[key]
  end

end

class MockConfigClient
  def initialize(config_values = {})
    @config_values = config_values
  end
  def get(key, default=nil)
    @config_values.fetch(key, default)
  end

  def get_config(key)
    Prefab::Config.new(value: @config_values[key], key: key)
  end

  def mock_this_config key, config_value
    @config_values[key] = config_value
  end
end

class MockConfigLoader
  def calc_config
  end
end


private

def default_ff_rule(variant_idx)
  [
    Prefab::Rule.new(
      criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
      variant_weights: [
        Prefab::VariantWeight.new(weight: 1000,
                                  variant_idx: variant_idx)
      ]
    )
  ]
end

def with_env(key, value)
  old_value = ENV[key]

  ENV[key] = value
ensure
  ENV[key] = old_value
end

def new_client(overrides = {})
  options = Prefab::Options.new(**{
    prefab_config_override_dir: "none",
    prefab_config_classpath_dir: "test",
    prefab_envs: ["unit_tests"],
    prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
  }.merge(overrides))

  Prefab::Client.new(options)
end
