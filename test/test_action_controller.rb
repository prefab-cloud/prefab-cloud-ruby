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
    assert_logged ['INFO  2023-08-09 15:18:12 -0400: rails.controller.request 200 MyController#index action=index controller=MyController db_runtime=0.05 format=application/html method=GET params={"p1"=>"v1"} path=/my?p1=v1 status=200 view_runtime=0.02']
  end


  def event
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
      Time.now,
      Time.now,
      99,
      status: 200,
      controller: 'MyController',
      action: 'index',
      format: 'application/html',
      method: 'GET',
      path: '/my?p1=v1',
      params: { 'p1' => 'v1' },
      db_runtime: 0.051123,
      view_runtime: 0.024555
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
