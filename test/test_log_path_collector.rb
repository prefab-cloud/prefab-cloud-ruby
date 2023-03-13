# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestLogPathCollector < Minitest::Test
  def test_sync
    Timecop.freeze do
      client = new_client(namespace: 'this.is.a.namespace')

      2.times { client.log.info('here is a message') }
      3.times { client.log.error('here is a message') }

      mock_request = Minitest::Mock.new

      mock_request.expect(:request, :return_value_we_do_not_care_about, [
                            Prefab::LoggerReportingService,
                            :send,
                            {
                              req_options: {},
                              params: Prefab::Loggers.new(
                                loggers: [Prefab::Logger.new(logger_name: 'test.test_log_path_collector.test_sync',
                                                             infos: 2, errors: 3)],
                                start_at: (Time.now.utc.to_f * 1000).to_i,
                                end_at: (Time.now.utc.to_f * 1000).to_i,
                                instance_hash: client.instance_hash,
                                namespace: 'this.is.a.namespace'
                              )
                            }
                          ])

      client.define_singleton_method(:request) do |*params|
        mock_request.request(*params)
      end

      client.log_path_collector.send(:sync)

      # let the flush thread run
      sleep 0.01 while mock_request.instance_eval { @actual_calls }.size.zero?

      mock_request.verify
    end
  end

  private

  def new_client(overrides = {})
    options = Prefab::Options.new(**{
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: ['unit_tests'],
      api_key: '123-development-yourapikey-SDK',
      collect_sync_interval: 1000 # we'll trigger sync manually in our test
    }.merge(overrides))

    Prefab::Client.new(options)
  end
end
