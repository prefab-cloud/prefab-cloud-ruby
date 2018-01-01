require 'test_helper'

class TestFeatureFlagClient < Minitest::Test

  def test_pct
    client = Prefab::FeatureFlagClient.new(MockBaseClient.new)
    Prefab::FeatureFlagClient.send(:public, :is_on?)

    flag = Prefab::FeatureFlag.new(feature: "FlagName", pct: 0.5)

    assert_equal false,
                 client.is_on?(flag.feature, "hashes high", [], flag)

    assert_equal true,
                 client.is_on?(flag.feature, "hashes low", [], flag)
  end


  def test_off
    client = Prefab::FeatureFlagClient.new(MockBaseClient.new)
    Prefab::FeatureFlagClient.send(:public, :is_on?)

    flag = Prefab::FeatureFlag.new(feature: "FlagName", pct: 0)

    assert_equal false,
                 client.is_on?(flag.feature, "hashes high", [], flag)

    assert_equal false,
                 client.is_on?(flag.feature, "hashes low", [], flag)
  end


  def test_on
    client = Prefab::FeatureFlagClient.new(MockBaseClient.new)
    Prefab::FeatureFlagClient.send(:public, :is_on?)

    flag = Prefab::FeatureFlag.new(feature: "FlagName", pct: 1)

    assert_equal true,
                 client.is_on?(flag.feature, "hashes high", [], flag)

    assert_equal true,
                 client.is_on?(flag.feature, "hashes low", [], flag)
  end

  def test_whitelist
    client = Prefab::FeatureFlagClient.new(MockBaseClient.new)
    Prefab::FeatureFlagClient.send(:public, :is_on?)

    flag = Prefab::FeatureFlag.new(feature: "FlagName", pct: 0, whitelisted: ["beta", "user:1", "user:3"])

    assert_equal false,
                 client.is_on?(flag.feature, "anything", [], flag)
    assert_equal true,
                 client.is_on?(flag.feature, "anything", ["beta"], flag)
    assert_equal true,
                 client.is_on?(flag.feature, "anything", ["alpha", "beta"], flag)
    assert_equal true,
                 client.is_on?(flag.feature, "anything", ["alpha", "user:1"], flag)
    assert_equal false,
                 client.is_on?(flag.feature, "anything", ["alpha", "user:2"], flag)

  end
end
