# frozen_string_literal: true

module CommonHelpers
  def with_env(key, value, &block)
    old_value = ENV.fetch(key, nil)

    ENV[key] = value
    block.call
  ensure
    ENV[key] = old_value
  end

  DEFAULT_NEW_CLIENT_OPTIONS = {
    prefab_config_override_dir: 'none',
    prefab_config_classpath_dir: 'test',
    prefab_envs: ['unit_tests'],
    prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
  }.freeze

  def new_client(overrides = {})
    config = overrides.delete(:config)
    project_env_id = overrides.delete(:project_env_id)

    options = Prefab::Options.new(**DEFAULT_NEW_CLIENT_OPTIONS.merge(overrides))

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

  FakeResponse = Struct.new(:status, :body)

  def wait_for_post_requests(client, max_wait: 2, sleep_time: 0.01)
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
end
