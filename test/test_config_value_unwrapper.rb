# frozen_string_literal: true

require 'test_helper'

class TestConfigValueUnwrapper < Minitest::Test
  CONFIG = PrefabProto::Config.new(
    key: 'config_key'
  )
  EMPTY_CONTEXT = Prefab::Context.new()
  DECRYPTION_KEY_NAME = "decryption.key"
  DECRYPTION_KEY_VALUE = Prefab::Encryption.generate_new_hex_key

  def setup
    super
    @mock_resolver = MockResolver.new
  end

  def test_unwrapping_int
    config_value = PrefabProto::ConfigValue.new(int: 123)
    assert_equal 123, unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_string
    config_value = PrefabProto::ConfigValue.new(string: 'abc')
    assert_equal 'abc', unwrap(config_value, CONFIG, EMPTY_CONTEXT)
    assert_equal 'abc', reportable_value(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_double
    config_value = PrefabProto::ConfigValue.new(double: 1.23)
    assert_equal 1.23, unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_bool
    config_value = PrefabProto::ConfigValue.new(bool: true)
    assert_equal true, unwrap(config_value, CONFIG, EMPTY_CONTEXT)

    config_value = PrefabProto::ConfigValue.new(bool: false)
    assert_equal false, unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_log_level
    config_value = PrefabProto::ConfigValue.new(log_level: :INFO)
    assert_equal :INFO, unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_string_list
    config_value = PrefabProto::ConfigValue.new(string_list: PrefabProto::StringList.new(values: %w[a b c]))
    assert_equal %w[a b c], unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_weighted_values
    # single value
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1]]))

    assert_equal 'abc', unwrap(config_value, CONFIG, EMPTY_CONTEXT)

    # multiple values, evenly distributed
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 1], ['ghi', 1]]))
    assert_equal 'def', unwrap(config_value, CONFIG, context_with_key('user:000'))
    assert_equal 'ghi', unwrap(config_value, CONFIG, context_with_key('user:456'))
    assert_equal 'abc', unwrap(config_value, CONFIG, context_with_key('user:789'))
    assert_equal 'ghi', unwrap(config_value, CONFIG, context_with_key('user:888'))

    # multiple values, unevenly distributed
    config_value = PrefabProto::ConfigValue.new(weighted_values: weighted_values([['abc', 1], ['def', 99], ['ghi', 1]]))
    assert_equal 'def', unwrap(config_value, CONFIG, context_with_key('user:123'))
    assert_equal 'def', unwrap(config_value, CONFIG, context_with_key('user:456'))
    assert_equal 'def', unwrap(config_value, CONFIG, context_with_key('user:789'))
    assert_equal 'def', unwrap(config_value, CONFIG, context_with_key('user:012'))
    assert_equal 'ghi', unwrap(config_value, CONFIG, context_with_key('user:428'))
    assert_equal 'abc', unwrap(config_value, CONFIG, context_with_key('user:548'))
  end

  def test_unwrapping_provided_values
    with_env('ENV_VAR_NAME', 'unit test value')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)
      assert_equal 'unit test value', unwrap(config_value, CONFIG, EMPTY_CONTEXT)
    end
  end

  def test_unwrapping_provided_values_of_type_string_list
    with_env('ENV_VAR_NAME', '["bob","cary"]')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)
      assert_equal ["bob", "cary"], unwrap(config_value, CONFIG, EMPTY_CONTEXT)
    end
  end

  def test_unwrapping_provided_values_coerces_to_int
    with_env('ENV_VAR_NAME', '42')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)
      assert_equal 42,  unwrap(config_value, config_of(PrefabProto::Config::ValueType::INT), EMPTY_CONTEXT)
    end
  end

  def test_unwrapping_provided_values_when_value_type_mismatch
    with_env('ENV_VAR_NAME', 'not an int')do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "ENV_VAR_NAME"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value)

      assert_raises Prefab::Errors::EnvVarParseError do
        unwrap(config_value, config_of(PrefabProto::Config::ValueType::INT), EMPTY_CONTEXT)
      end
    end
  end

  def test_coerce
    assert_equal "string", Prefab::ConfigValueUnwrapper.coerce_into_type("string", CONFIG, "ENV")
    assert_equal 42, Prefab::ConfigValueUnwrapper.coerce_into_type("42", CONFIG, "ENV")
    assert_equal false, Prefab::ConfigValueUnwrapper.coerce_into_type("false", CONFIG, "ENV")
    assert_equal 42.42, Prefab::ConfigValueUnwrapper.coerce_into_type("42.42", CONFIG, "ENV")
    assert_equal ["a","b"], Prefab::ConfigValueUnwrapper.coerce_into_type("['a','b']", CONFIG, "ENV")

    assert_equal "string", Prefab::ConfigValueUnwrapper.coerce_into_type("string", config_of(PrefabProto::Config::ValueType::STRING),"ENV")
    assert_equal "42", Prefab::ConfigValueUnwrapper.coerce_into_type("42", config_of(PrefabProto::Config::ValueType::STRING),"ENV")
    assert_equal "42.42", Prefab::ConfigValueUnwrapper.coerce_into_type("42.42", config_of(PrefabProto::Config::ValueType::STRING),"ENV")
    assert_equal 42, Prefab::ConfigValueUnwrapper.coerce_into_type("42", config_of(PrefabProto::Config::ValueType::INT),"ENV")
    assert_equal false, Prefab::ConfigValueUnwrapper.coerce_into_type("false", config_of(PrefabProto::Config::ValueType::BOOL),"ENV")
    assert_equal 42.42, Prefab::ConfigValueUnwrapper.coerce_into_type("42.42", config_of(PrefabProto::Config::ValueType::DOUBLE),"ENV")
    assert_equal ["a","b"], Prefab::ConfigValueUnwrapper.coerce_into_type("['a','b']", config_of(PrefabProto::Config::ValueType::STRING_LIST),"ENV")

    assert_raises Prefab::Errors::EnvVarParseError do
      Prefab::ConfigValueUnwrapper.coerce_into_type("not an int", config_of(PrefabProto::Config::ValueType::INT), "ENV")
    end
    assert_raises Prefab::Errors::EnvVarParseError do
      Prefab::ConfigValueUnwrapper.coerce_into_type("not bool", config_of(PrefabProto::Config::ValueType::BOOL), "ENV")
    end
    assert_raises Prefab::Errors::EnvVarParseError do
      Prefab::ConfigValueUnwrapper.coerce_into_type("not a double", config_of(PrefabProto::Config::ValueType::DOUBLE), "ENV")
    end
    assert_raises Prefab::Errors::EnvVarParseError do
      Prefab::ConfigValueUnwrapper.coerce_into_type("not a list", config_of(PrefabProto::Config::ValueType::STRING_LIST), "ENV")
    end
  end

  def test_unwrapping_provided_values_with_missing_env_var
    value = PrefabProto::Provided.new(
      source: :ENV_VAR,
      lookup: "NON_EXISTENT_ENV_VAR_NAME"
    )
    config_value = PrefabProto::ConfigValue.new(provided: value)
    assert_equal '', unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_unwrapping_encrypted_values_decrypts
    clear_text = "very secret stuff"
    encrypted = Prefab::Encryption.new(DECRYPTION_KEY_VALUE).encrypt(clear_text)
    config_value = PrefabProto::ConfigValue.new(string: encrypted, decrypt_with: "decryption.key")
    assert_equal clear_text, unwrap(config_value, CONFIG, EMPTY_CONTEXT)
  end

  def test_confidential
    config_value = PrefabProto::ConfigValue.new(confidential: true, string: "something confidential")
    assert reportable_value(config_value, CONFIG, EMPTY_CONTEXT).start_with? Prefab::ConfigValueUnwrapper::CONFIDENTIAL_PREFIX
  end

  def test_unwrap_confiential_provided
    with_env('PAAS_PASSWORD', "the password")do
      value = PrefabProto::Provided.new(
        source: :ENV_VAR,
        lookup: "PAAS_PASSWORD"
      )
      config_value = PrefabProto::ConfigValue.new(provided: value, confidential: true)
      assert_equal "the password", unwrap(config_value, CONFIG, EMPTY_CONTEXT)
      assert reportable_value(config_value, CONFIG, EMPTY_CONTEXT).start_with? Prefab::ConfigValueUnwrapper::CONFIDENTIAL_PREFIX
    end
  end

  private

  def config_of(value_type)
    PrefabProto::Config.new(
      key: 'config-key',
      value_type: value_type
    )
  end

  def context_with_key(key)
    Prefab::Context.new(user: { key: key })
  end

  def unwrap(config_value, config_key, context)
    Prefab::ConfigValueUnwrapper.deepest_value(config_value, config_key, context, @mock_resolver).unwrap
  end

  def reportable_value(config_value, config_key, context)
    Prefab::ConfigValueUnwrapper.deepest_value(config_value, config_key, context, @mock_resolver).reportable_value
  end

  class MockResolver
    def get(key)
      if DECRYPTION_KEY_NAME == key
        Prefab::Evaluation.new(config: PrefabProto::Config.new(key: key),
                               value: PrefabProto::ConfigValue.new(string: DECRYPTION_KEY_VALUE),
                                value_index: 0,
                                config_row_index: 0,
                                context: Prefab::Context.new,
                                resolver: self
        )

      else
        raise "unexpected key"
      end
    end
  end
end
