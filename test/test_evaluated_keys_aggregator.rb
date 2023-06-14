# frozen_string_literal: true

require 'test_helper'

class TestEvaluatedKeysAggregator < Minitest::Test
  MAX_WAIT = 2
  SLEEP_TIME = 0.01

  def test_push
    aggregator = Prefab::EvaluatedKeysAggregator.new(client: new_client, max_keys: 2, sync_interval: 1000)

    aggregator.push('key.1')
    aggregator.push('key.2')

    assert_equal 2, aggregator.data.size

    # we've reached the limit, so no more
    aggregator.push('key.3')
    assert_equal 2, aggregator.data.size
  end

  def test_sync
    client = new_client(namespace: 'this.is.a.namespace')

    client.get 'key.1', 'default', {}
    client.get 'key.1', 'default', {}
    client.get 'key.2', 'default', {}

    requests = []

    client.define_singleton_method(:post) do |*params|
      requests.push(params)

      OpenStruct.new(status: 200)
    end

    client.evaluated_keys_aggregator.send(:sync)

    # let the flush thread run

    wait_time = 0
    while requests.empty?
      wait_time += SLEEP_TIME
      sleep SLEEP_TIME

      raise "Waited #{MAX_WAIT} seconds for the flush thread to run, but it never did" if wait_time > MAX_WAIT
    end

    assert_equal [[
      '/api/v1/evaluated-keys',
      PrefabProto::EvaluatedKeys.new(
        keys: ['key.1', 'key.2'],
        namespace: 'this.is.a.namespace'
      )
    ]], requests
  end

  private

  def new_client(overrides = {})
    super(**{
      prefab_datasources: Prefab::Options::DATASOURCES::ALL,
      initialization_timeout_sec: 0,
      on_init_failure: Prefab::Options::ON_INITIALIZATION_FAILURE::RETURN,
      api_key: '123-development-yourapikey-SDK',
      collect_sync_interval: 1000, # we'll trigger sync manually in our test
      collect_keys: true
    }.merge(overrides))
  end
end
