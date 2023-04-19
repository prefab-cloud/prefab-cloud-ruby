# frozen_string_literal: true

require 'test_helper'

class TestClient < Minitest::Test
  def setup
    @client = new_client
  end

  def test_get
    assert_equal 'test sample value', @client.get('sample')
    assert_equal 123, @client.get('sample_int')
  end

  def test_get_with_default
    # A `false` value is not replaced with the default
    assert_equal false, @client.get('false_value', 'red')

    # A falsy value is not replaced with the default
    assert_equal 0, @client.get('zero_value', 'red')

    # A missing value returns the default
    assert_equal 'buckets', @client.get('missing_value', 'buckets')
  end

  def test_get_with_missing_default
    # it raises by default
    err = assert_raises(Prefab::Errors::MissingDefaultError) do
      assert_nil @client.get('missing_value')
    end

    assert_match(/No value found for key/, err.message)
    assert_match(/on_no_default/, err.message)

    # you can opt-in to return `nil` instead
    client = new_client(on_no_default: Prefab::Options::ON_NO_DEFAULT::RETURN_NIL)
    assert_nil client.get('missing_value')
  end

  def test_enabled
    assert_equal false, @client.enabled?('does_not_exist')
    assert_equal true, @client.enabled?('enabled_flag')
    assert_equal false, @client.enabled?('disabled_flag')
    assert_equal false, @client.enabled?('flag_with_a_value')
  end

  def test_ff_enabled_with_user_key_match
    assert_equal_context_and_jit(false, :enabled?, 'user_key_match', { user: { key: 'jimmy' } })
    assert_equal_context_and_jit(true, :enabled?, 'user_key_match', { user: { key: 'abc123' } })
    assert_equal_context_and_jit(true, :enabled?, 'user_key_match', { user: { key: 'xyz987' } })
  end

  def test_ff_enabled_with_attributes
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'gmail.com' })
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'prefab.cloud' })
    assert_equal_context_and_jit(false, :enabled?, 'just_my_domain', user: { domain: 'example.com' })
  end

  def test_ff_get_with_attributes
    assert_nil @client.get('just_my_domain', 'abc123', user: { domain: 'gmail.com' })
    assert_equal 'DEFAULT', @client.get('just_my_domain', 'abc123', { user: { domain: 'gmail.com' } }, 'DEFAULT')

    assert_equal_context_and_jit('new-version', :get, 'just_my_domain', { user: { domain: 'prefab.cloud' } })
    assert_equal_context_and_jit('new-version', :get, 'just_my_domain', { user: { domain: 'example.com' } })
  end

  def test_getting_feature_flag_value
    assert_equal false, @client.enabled?('flag_with_a_value')
    assert_equal 'all-features', @client.get('flag_with_a_value')
  end

  def test_initialization_with_an_options_object
    options_hash = {
      namespace: 'test-namespace',
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    }

    options = Prefab::Options.new(options_hash)

    client = Prefab::Client.new(options)

    assert_equal client.namespace, 'test-namespace'
  end

  def test_initialization_with_a_hash
    options_hash = {
      namespace: 'test-namespace',
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    }

    client = Prefab::Client.new(options_hash)

    assert_equal client.namespace, 'test-namespace'
  end

  private

  def assert_equal_context_and_jit(expected, method, key, context)
    assert_equal expected, @client.send(method, key, context)

    Prefab::Context.with_context(context) do
      assert_equal expected, @client.send(method, key)
    end
  end
end
