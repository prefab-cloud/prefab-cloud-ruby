# frozen_string_literal: true

require 'test_helper'

class JavascriptStubTest < Minitest::Test
  PROJECT_ENV_ID = 1
  DEFAULT_VALUE = 'default_value'
  DEFAULT_VALUE_CONFIG = PrefabProto::ConfigValue.new(string: DEFAULT_VALUE)
  TRUE_CONFIG = PrefabProto::ConfigValue.new(bool: true)
  FALSE_CONFIG = PrefabProto::ConfigValue.new(bool: false)
  DEFAULT_ROW = PrefabProto::ConfigRow.new(
    values: [
      PrefabProto::ConditionalValue.new(value: DEFAULT_VALUE_CONFIG)
    ]
  )

  def setup
    super

    log_level = PrefabProto::Config.new(
      id: 999,
      key: 'log-level',
      config_type: PrefabProto::ConfigType::LOG_LEVEL,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              criteria: [],
              value: PrefabProto::ConfigValue.new(log_level: PrefabProto::LogLevel::INFO)
            )
          ]
        )
      ]
    )

    config_for_sdk = PrefabProto::Config.new(
      id: 123,
      key: 'basic-config',
      config_type: PrefabProto::ConfigType::CONFIG,
      rows: [DEFAULT_ROW],
      send_to_client_sdk: true
    )

    config_not_for_sdk = PrefabProto::Config.new(
      id: 787,
      key: 'non-sdk-basic-config',
      config_type: PrefabProto::ConfigType::CONFIG,
      rows: [DEFAULT_ROW]
    )

    ff = PrefabProto::Config.new(
      id: 456,
      key: 'feature-flag',
      config_type: PrefabProto::ConfigType::FEATURE_FLAG,
      rows: [
        PrefabProto::ConfigRow.new(
          values: [
            PrefabProto::ConditionalValue.new(
              value: TRUE_CONFIG,
              criteria: [
                PrefabProto::Criterion.new(
                  operator: PrefabProto::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['hotmail.com', 'gmail.com']),
                  property_name: 'user.email'
                )
              ]
            ),
            PrefabProto::ConditionalValue.new(value: FALSE_CONFIG)
          ]
        )
      ]
    )

    @client = new_client(
      config: [log_level, config_for_sdk, config_not_for_sdk, ff],
      project_env_id: PROJECT_ENV_ID,
      collect_evaluation_summaries: true,
      prefab_config_override_dir: '/tmp',
      prefab_config_classpath_dir: '/tmp',
      context_upload_mode: :periodic_example,
      allow_telemetry_in_local_mode: true
    )
  end

  def test_bootstrap
    result = Prefab::JavaScriptStub.new(@client).bootstrap({})

    assert_equal %(
window._prefabBootstrap = {
  configs: {"basic-config":"default_value","feature-flag":false},
  context: {}
}
    ).strip, result.strip

    result = Prefab::JavaScriptStub.new(@client).bootstrap({ user: { email: 'gmail.com' } })

    assert_equal %(
window._prefabBootstrap = {
  configs: {"basic-config":"default_value","feature-flag":true},
  context: {"user":{"email":"gmail.com"}}
}
    ).strip, result.strip
  end

  def test_generate_stub
    result = Prefab::JavaScriptStub.new(@client).generate_stub({})

    assert_equal %(
window.prefab = window.prefab || {};
window.prefab.config = {"basic-config":"default_value","feature-flag":false};
window.prefab.get = function(key) {
  return window.prefab.config[key];
};
window.prefab.isEnabled = function(key) {
  return window.prefab.config[key] === true;
};
    ).strip, result.strip

    result = Prefab::JavaScriptStub.new(@client).generate_stub({ user: { email: 'gmail.com' } })

    assert_equal %(
window.prefab = window.prefab || {};
window.prefab.config = {"basic-config":"default_value","feature-flag":true};
window.prefab.get = function(key) {
  return window.prefab.config[key];
};
window.prefab.isEnabled = function(key) {
  return window.prefab.config[key] === true;
};

    ).strip, result.strip
  end
end
