# frozen_string_literal: true

require 'test_helper'

class TestActionController < Minitest::Test
  def setup
    super
    client = new_client(config: log_level_config("log-level.rails.controller", "INFO"))
    @subscriber = Prefab::LogSubscribers::ActionController.new
  end

  def test_load
    @subscriber.process_action(event)
    assert_logged ["INFO  2023-08-09 15:18:12 -0400: rails.controller.request 200 HomeController#index action=index controller=HomeController db_runtime=0.02 format=application/json method=GET params={\"foo\"=>\"bar\"} path=/home?foo=bar status=200 view_runtime=0.01"]
  end


  def event
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
      Time.now,
      Time.now,
      2,
      status: 200,
      controller: 'HomeController',
      action: 'index',
      format: 'application/json',
      method: 'GET',
      path: '/home?foo=bar',
      params: { 'foo' => 'bar' },
      db_runtime: 0.021123,
      view_runtime: 0.014555
    )
  end

  def log_level_config(path, level)
      PrefabProto::Config.new(
        id: 123,
        key: path,
        config_type: PrefabProto::ConfigType::LOG_LEVEL,
        rows: [
          PrefabProto::ConfigRow.new(
            values: [
              PrefabProto::ConditionalValue.new(
                value: PrefabProto::ConfigValue.new(log_level: level)
              )
            ]
          )
        ]
      )
  end
end
