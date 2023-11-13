# frozen_string_literal: true

require 'test_helper'

class TestActionController < Minitest::Test
  def setup
    super
  end

  def test_load
    new_client(config: log_level_config("log-level.rails.controller", "INFO"))
    @subscriber = Prefab::LogSubscribers::ActionControllerSubscriber.new
    @subscriber.process_action(event)
    assert_logged ['INFO  2023-08-09 15:18:12 -0400: rails.controller.request 200 MyController#index action=index controller=MyController db_runtime=0.05 format=application/html method=GET params={"p1"=>"v1"} req_path=/my?p1=v1 status=200 view_runtime=0.02']
  end

  def test_json
    new_client(config: log_level_config("log-level.rails.controller", "INFO"), log_formatter: Prefab::Options::JSON_LOG_FORMATTER)
    @subscriber = Prefab::LogSubscribers::ActionControllerSubscriber.new
    event = ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
      Time.now,
      Time.now,
      99,
      path: '/original_path',
      )
    @subscriber.process_action(event)
    assert_logged ["{\"severity\":\"INFO\",\"datetime\":\"2023-08-09 15:18:12 -0400\",\"path\":\"rails.controller.request\",\"message\":\" #\",\"req_path\":\"/original_path\"}"]

  end

  def test_funny_params
    new_client(config: log_level_config("log-level.rails.controller", "INFO"))
    @subscriber = Prefab::LogSubscribers::ActionControllerSubscriber.new
    event = ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
      Time.now,
      Time.now,
      99,
      params: "foo"
      )
    @subscriber.process_action(event)
    assert_logged ['INFO  2023-08-09 15:18:12 -0400: rails.controller.request  # params=foo']
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
