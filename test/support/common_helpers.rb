# frozen_string_literal: true

module CommonHelpers
  require 'timecop'

  def setup
    $oldstderr, $stderr = $stderr, StringIO.new

    $logs = StringIO.new
    SemanticLogger.add_appender(io: $logs, filter: Prefab.log_filter)
    SemanticLogger.sync!
    Timecop.freeze('2023-08-09 15:18:12 -0400')
  end

  def teardown
    if $logs && !$logs.string.empty?
      log_lines = $logs.string.split("\n").reject do |line|
        line.match(/Prefab::ConfigClient -- No success loading checkpoints/)
      end

      if log_lines.size > 0
        $logs = nil
        raise "Unexpected logs. Handle logs with assert_logged\n\n#{log_lines}"
      end
    end

    if $stderr != $oldstderr && !$stderr.string.empty?
      # we ignore 2.X because of the number of `instance variable @xyz not initialized` warnings
      if !RUBY_VERSION.start_with?('2.')
        raise "Unexpected stderr. Handle stderr with assert_stderr\n\n#{$stderr.string}"
      end
    end

    $stderr = $oldstderr

    Timecop.return
  end

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

    Prefab::Client.new(prefab_options(overrides)).tap do |client|
      inject_config(client, config) if config

      client.resolver.project_env_id = project_env_id if project_env_id
    end
  end

  def prefab_options(overrides = {})
    Prefab::Options.new(
      **DEFAULT_NEW_CLIENT_OPTIONS.merge(overrides)
    )
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

  def wait_for(condition, max_wait: 2, sleep_time: 0.01)
    wait_time = 0
    while !condition.call
      wait_time += sleep_time
      sleep sleep_time

      raise "Waited #{max_wait} seconds for the condition to be true, but it never was" if wait_time > max_wait
    end
  end

  def wait_for_post_requests(client, max_wait: 2, sleep_time: 0.01)
    # we use ivars to avoid re-mocking the post method on subsequent calls
    client.instance_variable_set("@_requests", [])

    if !client.instance_variable_get("@_already_faked_post")
      client.define_singleton_method(:post) do |*params|
        @_requests.push(params)

        FakeResponse.new(200, '')
      end
    end

    client.instance_variable_set("@_already_faked_post", true)

    yield

    # let the flush thread run
    wait_for -> { client.instance_variable_get("@_requests").size > 0 }, max_wait: max_wait, sleep_time: sleep_time

    client.instance_variable_get("@_requests")
  end

  def assert_summary(client, data)
    raise 'Evaluation summary aggregator not enabled' unless client.evaluation_summary_aggregator

    assert_equal data, client.evaluation_summary_aggregator.data
  end

  def assert_example_contexts(client, data)
    raise 'Example contexts aggregator not enabled' unless client.example_contexts_aggregator

    assert_equal data, client.example_contexts_aggregator.data
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

  def assert_logged(expected)
    # we do a uniq here because logging can happen in a separate thread so the
    # number of times a log might happen could be slightly variable.
    actuals = $logs.string.split("\n").uniq
    expected.each do |expectation|
      matched = false

      actuals.each do |actual|
        matched = true if actual.match(expectation)
      end

      assert(matched, "expectation: #{expectation}, got: #{actuals}")
    end
    # mark nil to indicate we handled it
    $logs = nil
  end

  def assert_stderr(expected)
    assert ($stderr.string.split("\n").uniq & expected).size > 0

    # Ruby 2.X has a lot of warnings about instance variables not being
    # initialized so we don't try to assert on stderr for those versions.
    # Instead we just stop after asserting that our expected errors are
    # included in the output.
    if RUBY_VERSION.start_with?('2.')
      puts $stderr.string
      return
    end

    assert_equal expected, $stderr.string.split("\n")

    # restore since we've handled it
    $stderr = $oldstderr
  end
end
