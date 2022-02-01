require 'test_helper'

class TestFeatureFlagClient < Minitest::Test

  def setup
    super
    @client = Prefab::FeatureFlagClient.new(MockBaseClient.new)
    Prefab::FeatureFlagClient.send(:public, :is_on?) #publicize for testing
  end

  def test_pct
    feature = "FlagName"

    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_value: Prefab::FeatureFlagVariant.new(bool: false),
      default: Prefab::VariantDistribution.new(variant_weights:
                                                 Prefab::VariantWeights.new(weights: [
                                                   Prefab::VariantWeight.new(weight: 500,
                                                                             variant: Prefab::FeatureFlagVariant.new(bool: true)),
                                                   Prefab::VariantWeight.new(weight: 500,
                                                                             variant: Prefab::FeatureFlagVariant.new(bool: false)),
                                                 ]
                                                 )
      )
    )

    assert_equal false,
                 @client.is_on?(feature, "hashes high", [], flag)
    assert_equal true,
                 @client.is_on?(feature, "hashes low", [], flag)
  end

  def test_basic_active_inactive
    feature = "FlagName"
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_value: Prefab::FeatureFlagVariant.new(bool: false),
      default: Prefab::VariantDistribution.new(variant: Prefab::FeatureFlagVariant.new(bool: true))
    )
    assert_equal true,
                 @client.is_on?(feature, "hashes high", [], flag)
    assert_equal true,
                 @client.is_on?(feature, "hashes low", [], flag)

    flag = Prefab::FeatureFlag.new(
      active: false,
      inactive_value: Prefab::FeatureFlagVariant.new(bool: false),
      default: Prefab::VariantDistribution.new(variant: Prefab::FeatureFlagVariant.new(bool: true))
    )
    assert_equal false,
                 @client.is_on?(feature, "hashes high", [], flag)
    assert_equal false,
                 @client.is_on?(feature, "hashes low", [], flag)
  end

  def test_user_targets

    feature = "FlagName"
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_value: Prefab::FeatureFlagVariant.new(string: "inactive"),
      user_targets: [
        variant: Prefab::FeatureFlagVariant.new(string: "user target"),
        identifiers: ["user:1", "user:3"]
      ],
      default: Prefab::VariantDistribution.new(variant: Prefab::FeatureFlagVariant.new(string: "default"))
    )

    assert_equal "user target",
                 @client.get(feature, "user:1", [], flag)
    assert_equal "default",
                 @client.get(feature, "user:2", [], flag)
    assert_equal "user target",
                 @client.get(feature, "user:3", [], flag)
  end
end
