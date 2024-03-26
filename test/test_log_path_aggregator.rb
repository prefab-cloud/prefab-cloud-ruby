# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestLogPathAggregator < Minitest::Test
  MAX_WAIT = 2
  SLEEP_TIME = 0.01

  def test_push
    client = new_client(prefab_datasources: Prefab::Options::DATASOURCES::ALL,)
    aggregator = Prefab::LogPathAggregator.new(client: client, max_paths: 2, sync_interval: 1000)

    aggregator.push('test.test_log_path_aggregator.test_push.1', ::Logger::INFO)
    aggregator.push('test.test_log_path_aggregator.test_push.2', ::Logger::DEBUG)

    assert_equal 2, aggregator.data.size

    # we've reached the limit, so no more
    aggregator.push('test.test_log_path_aggregator.test_push.3', ::Logger::INFO)
    assert_equal 2, aggregator.data.size
  end

  def test_sync
    Timecop.freeze do
      client = new_client(namespace: 'this.is.a.namespace', allow_telemetry_in_local_mode: true)

      2.times { client.log.should_log? 1, "test.test_log_path_aggregator.test_sync" }
      3.times { client.log.should_log? 3, "test.test_log_path_aggregator.test_sync" }

      requests = wait_for_post_requests(client) do
        client.log_path_aggregator.send(:sync)
      end

      assert_equal '/api/v1/known-loggers', requests[0][0]
      sent_logger = requests[0][1]
      assert_equal 'this.is.a.namespace', sent_logger.namespace
      assert_equal Prefab::TimeHelpers.now_in_ms, sent_logger.start_at
      assert_equal Prefab::TimeHelpers.now_in_ms, sent_logger.end_at
      assert_equal client.instance_hash, sent_logger.instance_hash
      assert_includes sent_logger.loggers,
                      PrefabProto::Logger.new(logger_name: 'test.test_log_path_aggregator.test_sync', infos: 2,
                                              errors: 3)
    end
  end

  private

  def new_client(overrides = {})
    super(**{
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY,
      api_key: '123-development-yourapikey-SDK',
      collect_max_paths: 1000,
      collect_sync_interval: 1000 # we'll trigger sync manually in our test
    }.merge(overrides))
  end
end
