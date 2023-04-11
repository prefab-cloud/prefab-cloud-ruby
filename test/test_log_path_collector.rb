# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestLogPathCollector < Minitest::Test
  MAX_WAIT = 2
  SLEEP_TIME = 0.01

  def test_sync
    Timecop.freeze do
      client = new_client(namespace: 'this.is.a.namespace')

      2.times { client.log.info('here is a message') }
      3.times { client.log.error('here is a message') }

      requests = []

      client.define_singleton_method(:post) do |*params|
        requests.push(params)
      end

      client.log_path_collector.send(:sync)

      # let the flush thread run

      wait_time = 0
      while requests.length == 0
        wait_time += SLEEP_TIME
        sleep SLEEP_TIME

        raise "Waited #{MAX_WAIT} seconds for the flush thread to run, but it never did" if wait_time > MAX_WAIT
      end

      assert_equal requests, [[
        '/api/v1/known-loggers',
        Prefab::Loggers.new(
          loggers: [Prefab::Logger.new(logger_name: 'test.test_log_path_collector.test_sync',
                                       infos: 2, errors: 3)],
          start_at: (Time.now.utc.to_f * 1000).to_i,
          end_at: (Time.now.utc.to_f * 1000).to_i,
          instance_hash: client.instance_hash,
          namespace: 'this.is.a.namespace'
        )
      ]]
    end
  end

  private

  def new_client(overrides = {})
    options = Prefab::Options.new(**{
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: ['unit_tests'],
      api_key: '123-development-yourapikey-SDK'
    }.merge(overrides))

    Prefab::Client.new(options)
  end
end
