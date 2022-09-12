# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/focus'
require 'minitest/reporters'
Minitest::Reporters.use!

require 'prefab-cloud-ruby'

class MockBaseClient
  STAGING_ENV_ID = 1
  PRODUCTION_ENV_ID = 2
  TEST_ENV_ID = 3
  attr_reader :namespace
  attr_reader :logger
  attr_reader :config_client
  attr_reader :options

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

  def log_internal(level, message); end

  def config_value(key)
    @config_values[key]
  end

  def stats
    Prefab::NoopStats.new
  end
end

class MockConfigClient
  def initialize(config_values = {})
    @config_values = config_values
    @variants = {}
  end

  def get(key, default = nil)
    @config_values.fetch(key, default)
  end

  def get_config(key)
    Prefab::Config.new(value: @config_values[key], key: key)
  end

  def get_config_obj(key)
    Prefab::Config.new(key: key, variants: @variants[key]) # we only use this for variants
  end

  def mock_this_config(key, config_value, variants = nil)
    @config_values[key] = config_value
    @variants[key] = variants
  end
end

class MockConfigLoader
  def calc_config; end
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

def with_env(key, value, &block)
  old_value = ENV[key]

  ENV[key] = value
  block.call
ensure
  ENV[key] = old_value
end

def new_client(overrides = {})
  options = Prefab::Options.new(**{
    prefab_config_override_dir: 'none',
    prefab_config_classpath_dir: 'test',
    prefab_envs: ['unit_tests'],
    prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
  }.merge(overrides))

  Prefab::Client.new(options)
end
