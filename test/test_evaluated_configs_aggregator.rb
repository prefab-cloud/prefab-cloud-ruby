# frozen_string_literal: true

require 'test_helper'
require 'timecop'

class TestEvaluatedConfigsAggregator < Minitest::Test
  MAX_WAIT = 2
  SLEEP_TIME = 0.01

  def test_push
    aggregator = Prefab::EvaluatedConfigsAggregator.new(client: new_client, max_configs: 2, sync_interval: 1000)

    aggregator.push([])
    aggregator.push([])

    assert_equal 2, aggregator.data.size

    # we've reached the limit, so no more
    aggregator.push([])
    assert_equal 2, aggregator.data.size
  end

  def test_coerce_to_proto
    aggregator = Prefab::EvaluatedConfigsAggregator.new(client: new_client, max_configs: 2, sync_interval: 2)

    Timecop.freeze do
      coerced = aggregator.coerce_to_proto([
                                             CONFIG_1,
                                             DESIRED_VALUE,
                                             Prefab::Context.new(CONTEXT)
                                           ])

      assert_equal PrefabProto::EvaluatedConfig.new(
        key: CONFIG_1.key,
        config_version: CONFIG_1.id,
        result: DESIRED_VALUE,
        context: PrefabProto::ContextSet.new(
          contexts: [
            PrefabProto::Context.new(
              type: "user",
              values: {
                "id" => PrefabProto::ConfigValue.new(int: 1),
                "email_suffix" => PrefabProto::ConfigValue.new(string: "hotmail.com")
              }
            ),
            PrefabProto::Context.new(
              type: "team",
              values: {
                "id" => PrefabProto::ConfigValue.new(int: 2),
                "name" => PrefabProto::ConfigValue.new(string: "team-name")
              }
            ),
            PrefabProto::Context.new(
              type: "prefab",
              values: {
                "current-time" => PrefabProto::ConfigValue.new(int: Prefab::TimeHelpers.now_in_ms),
              }
            ),
          ]
        ),
        timestamp: Prefab::TimeHelpers.now_in_ms
      ), coerced
    end
  end

  def test_sync
    client = new_client(namespace: 'this.is.a.namespace')

    inject_config(client, CONFIG_1)
    inject_config(client, CONFIG_2)
    inject_project_env_id(client, PROJECT_ENV_ID)

    client.get CONFIG_1.key, 'default', CONTEXT
    client.get CONFIG_1.key, 'default', { user: { email_suffix: "example.com" }, device: { mobile: true } }
    client.get CONFIG_2.key, 'default', CONTEXT

    # logger items are not reported
    client.get "#{Prefab::ConfigClient::LOGGING_KEY_PREFIX}something", 'default', CONTEXT

    requests = wait_for_post_requests(client) do
      client.evaluated_configs_aggregator.send(:sync)
    end

    assert_equal [[
      '/api/v1/evaluated-configs',
      PrefabProto::EvaluatedConfigs.new(
        configs: [
          PrefabProto::EvaluatedConfig.new(
            key: CONFIG_1.key,
            config_version: CONFIG_1.id,
            result: DESIRED_VALUE,
            context: PrefabProto::ContextSet.new(
              contexts: [
                PrefabProto::Context.new(
                  type: "user",
                  values: {
                    "id" => PrefabProto::ConfigValue.new(int: 1),
                    "email_suffix" => PrefabProto::ConfigValue.new(string: "hotmail.com")
                  }
                ),
                PrefabProto::Context.new(
                  type: "team",
                  values: {
                    "id" => PrefabProto::ConfigValue.new(int: 2),
                    "name" => PrefabProto::ConfigValue.new(string: "team-name")
                  }
                ),
                PrefabProto::Context.new(
                  type: "prefab",
                  values: {
                    "current-time" => PrefabProto::ConfigValue.new(int: Prefab::TimeHelpers.now_in_ms),
                    "namespace" => PrefabProto::ConfigValue.new(string: "this.is.a.namespace"),
                  }
                ),
              ]
            ),
            timestamp: Prefab::TimeHelpers.now_in_ms
          ),
          PrefabProto::EvaluatedConfig.new(
            key: CONFIG_1.key,
            config_version: CONFIG_1.id,
            result: DEFAULT_VALUE,
            context: PrefabProto::ContextSet.new(
              contexts: [
                PrefabProto::Context.new(
                  type: "user",
                  values: {
                    "email_suffix" => PrefabProto::ConfigValue.new(string: "example.com")
                  }
                ),
                PrefabProto::Context.new(
                  type: "device",
                  values: {
                    "mobile" => PrefabProto::ConfigValue.new(bool: true),
                  }
                ),
                PrefabProto::Context.new(
                  type: "prefab",
                  values: {
                    "current-time" => PrefabProto::ConfigValue.new(int: Prefab::TimeHelpers.now_in_ms),
                    "namespace" => PrefabProto::ConfigValue.new(string: "this.is.a.namespace"),
                  }
                )

              ]
            ),
            timestamp: Prefab::TimeHelpers.now_in_ms
          ),

          PrefabProto::EvaluatedConfig.new(
            key: CONFIG_2.key,
            config_version: CONFIG_2.id,
            result: DEFAULT_VALUE,
            context: PrefabProto::ContextSet.new(
              contexts: [
                PrefabProto::Context.new(
                  type: "user",
                  values: {
                    "id" => PrefabProto::ConfigValue.new(int: 1),
                    "email_suffix" => PrefabProto::ConfigValue.new(string: "hotmail.com")
                  }
                ),
                PrefabProto::Context.new(
                  type: "team",
                  values: {
                    "id" => PrefabProto::ConfigValue.new(int: 2),
                    "name" => PrefabProto::ConfigValue.new(string: "team-name")
                  }
                ),
                PrefabProto::Context.new(
                  type: "prefab",
                  values: {
                    "current-time" => PrefabProto::ConfigValue.new(int: Prefab::TimeHelpers.now_in_ms),
                    "namespace" => PrefabProto::ConfigValue.new(string: "this.is.a.namespace"),
                  }
                )
              ]
            ),
            timestamp: Prefab::TimeHelpers.now_in_ms
          )

        ]
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
      collect_evaluations: true
    }.merge(overrides))
  end

  DEFAULT_VALUE = PrefabProto::ConfigValue.new(string: '❌')

  DESIRED_VALUE = PrefabProto::ConfigValue.new(string: "✅")

  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(
        value: DEFAULT_VALUE
      )
    ]
  )

  PROJECT_ENV_ID = 1

  CONFIG_1 = PrefabProto::Config.new(
    id: 1,
    key: "key.1",
    rows: [
      PrefabProto::ConfigRow.new(
        project_env_id: PROJECT_ENV_ID,
        values: [
          PrefabProto::ConditionalValue.new(
            criteria: [
              PrefabProto::Criterion.new(
                operator: PrefabProto::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                value_to_match: string_list(['hotmail.com', 'gmail.com']),
                property_name: 'user.email_suffix'
              )
            ],
            value: DESIRED_VALUE
          )
        ]
      ),
      DEFAULT_ROW
    ]
  )

  CONFIG_2 = PrefabProto::Config.new(
    id: 2,
    key: "key.2",
    rows: [DEFAULT_ROW,]
  )

  CONTEXT = {
    user: {
      id: 1,
      email_suffix: 'hotmail.com'
    },
    team: {
      id: 2,
      name: 'team-name'
    }
  }
end
