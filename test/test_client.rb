# frozen_string_literal: true
require 'test_helper'

class TestClient < Minitest::Test
  def setup
    @client = new_client
  end

  def test_get
    assert_equal "test sample value", @client.get("sample")
    assert_equal 123, @client.get("sample_int")
  end

  def test_get_with_default
    # A `false` value is not replaced with the default
    assert_equal false, @client.get("false_value", "red")

    # A falsy value is not replaced with the default
    assert_equal 0, @client.get("zero_value", "red")

    # A missing value returns the default
    assert_equal "buckets", @client.get("missing_value", "buckets")
  end

  def test_get_with_missing_default
    # it raises by default
    err = assert_raises(Prefab::Errors::MissingDefaultError) do
      assert_nil @client.get("missing_value")
    end

    assert_match(/No value found for key/, err.message)
    assert_match(/on_no_default/, err.message)

    # you can opt-in to return `nil` instead
    client = new_client(on_no_default: Prefab::Options::ON_NO_DEFAULT::RETURN_NIL)
    assert_nil client.get("missing_value")
  end

  def test_enabled
    assert_equal false, @client.enabled?("does_not_exist")
    assert_equal true, @client.enabled?("enabled_flag")
    assert_equal false, @client.enabled?("disabled_flag")
    assert_equal false, @client.enabled?("flag_with_a_value")
  end

  def test_ff_enabled_with_lookup_key
    assert_equal false, @client.enabled?("in_lookup_key", "jimmy")
    assert_equal true, @client.enabled?("in_lookup_key", "abc123")
    assert_equal true, @client.enabled?("in_lookup_key", "xyz987")
  end

  def test_ff_get_with_lookup_key
    assert_nil @client.get("in_lookup_key", "jimmy")
    assert_equal "DEFAULT", @client.get("in_lookup_key", "jimmy", {}, "DEFAULT")

    assert_equal true, @client.get("in_lookup_key", "abc123")
    assert_equal true, @client.get("in_lookup_key", "xyz987")
  end

  def test_ff_enabled_with_attributes
    assert_equal false, @client.enabled?("just_my_domain", "abc123", { domain: "gmail.com" })
    assert_equal false, @client.enabled?("just_my_domain", "abc123", { domain: "prefab.cloud" })
    assert_equal false, @client.enabled?("just_my_domain", "abc123", { domain: "example.com" })
  end

  def test_ff_get_with_attributes
    assert_nil @client.get("just_my_domain", "abc123", { domain: "gmail.com" })
    assert_equal "DEFAULT", @client.get("just_my_domain", "abc123", { domain: "gmail.com" }, "DEFAULT")

    assert_equal "new-version", @client.get("just_my_domain", "abc123", { domain: "prefab.cloud" })
    assert_equal "new-version", @client.get("just_my_domain", "abc123", { domain: "example.com" })
  end

  def test_getting_feature_flag_value
    assert_equal false, @client.enabled?("flag_with_a_value")
    assert_equal "all-features", @client.get("flag_with_a_value")
  end

  def test_ssl_certs
    certs = @client.send(:ssl_certs).split("-----BEGIN CERTIFICATE-----")

    # This is a smoke test to make sure multiple certs are loaded
    assert certs.length > 1
  end

  private

  def new_client(overrides = {})
    options = Prefab::Options.new(**{
      prefab_config_override_dir: "none",
      prefab_config_classpath_dir: "test",
      prefab_envs: ["unit_tests"],
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    }.merge(overrides))

    Prefab::Client.new(options)
  end
end
