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
    assert_raises(Prefab::Errors::MissingDefaultError) do
      assert_nil @client.get("missing_value")
    end

    # you can opt-in to return `nil` instead
    client = new_client(on_no_default: Prefab::Options::ON_NO_DEFAULT::RETURN_NIL)
    assert_nil client.get("missing_value")
  end

  private

  def new_client(overrides = {})
    options = Prefab::Options.new(**{
      prefab_config_override_dir: "none",
      prefab_config_classpath_dir: "test",
      defaults_env: "unit_tests",
      prefab_datasources: Prefab::Options::DATASOURCES::LOCAL_ONLY
    }.merge(overrides))

    Prefab::Client.new(options)
  end
end
