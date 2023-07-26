# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/focus'
require 'minitest/reporters'
Minitest::Reporters.use!

require 'prefab-cloud-ruby'

FakeResponse = Struct.new(:status, :body)

class MockBaseClient
  STAGING_ENV_ID = 1
  PRODUCTION_ENV_ID = 2
  TEST_ENV_ID = 3
  attr_reader :namespace, :logger, :config_client, :options, :posts

  def initialize(options = Prefab::Options.new)
    @options = options
    @namespace = namespace
    @logger = Prefab::LoggerClient.new($stdout)
    @config_client = MockConfigClient.new
    @posts = []
  end

  def instance_hash
    'mock-base-client-instance-hash'
  end

  def project_id
    1
  end

  def post(_, _)
    raise 'Use wait_for_post_requests'
  end

  def log
    @logger
  end

  def log_internal(level, message); end

  def context_shape_aggregator; end

  def evaluated_keys_aggregator; end

  def evaluated_configs_aggregator; end

  def evaluation_summary_aggregator; end

  def config_value(key)
    @config_values[key]
  end
end

class MockConfigClient
  def initialize(config_values = {})
    @config_values = config_values
  end

  def get(key, default = nil)
    @config_values.fetch(key, default)
  end

  def get_config(key)
    PrefabProto::Config.new(value: @config_values[key], key: key)
  end

  def mock_this_config(key, config_value)
    @config_values[key] = config_value
  end
end

class MockConfigLoader
  def calc_config; end
end

private

def with_env(key, value, &block)
  old_value = ENV.fetch(key, nil)

  ENV[key] = value
  block.call
ensure
  ENV[key] = old_value
end

def new_client(overrides = {})
  config = overrides.delete(:config)
  project_env_id = overrides.delete(:project_env_id)

  options = Prefab::Options.new(**{
    prefab_config_override_dir: 'none',
    prefab_config_classpath_dir: 'test',
    prefab_envs: ['unit_tests'],
    prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
  }.merge(overrides))

  Prefab::Client.new(options).tap do |client|
    inject_config(client, config) if config

    client.resolver.project_env_id = project_env_id if project_env_id
  end
end

def string_list(values)
  PrefabProto::ConfigValue.new(string_list: PrefabProto::StringList.new(values: values))
end

def inject_config(client, config)
  resolver = client.config_client.instance_variable_get('@config_resolver')
  store = resolver.instance_variable_get('@local_store')

  Array(config).each do |c|
    store[c.key] = { config: c }
  end
end

def inject_project_env_id(client, project_env_id)
  resolver = client.config_client.instance_variable_get('@config_resolver')
  resolver.project_env_id = project_env_id
end

def wait_for_post_requests(client)
  max_wait = 2
  sleep_time = 0.01

  requests = []

  client.define_singleton_method(:post) do |*params|
    requests.push(params)

    FakeResponse.new(200, '')
  end

  yield

  # let the flush thread run
  wait_time = 0
  while requests.empty?
    wait_time += sleep_time
    sleep sleep_time

    raise "Waited #{max_wait} seconds for the flush thread to run, but it never did" if wait_time > max_wait
  end

  requests
end

def assert_summary(client, data)
  raise 'Evaluation summary aggregator not enabled' unless client.evaluation_summary_aggregator

  assert_equal data, client.evaluation_summary_aggregator.data
end

def weighted_values(values_and_weights, hash_by_property_name: 'user.key')
  values = values_and_weights.map do |value, weight|
    weighted_value(value, weight)
  end

  PrefabProto::WeightedValues.new(weighted_values: values, hash_by_property_name: hash_by_property_name)
end

def weighted_value(string, weight)
  PrefabProto::WeightedValue.new(
    value: PrefabProto::ConfigValue.new(string: string), weight: weight
  )
end

def context(properties)
  Prefab::Context.new(properties)
end
