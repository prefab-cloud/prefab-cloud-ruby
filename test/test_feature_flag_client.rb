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
      variants: [
        Prefab::FeatureFlagVariant.new(bool: false),
        Prefab::FeatureFlagVariant.new(bool: true)
      ],
      inactive_variant_idx: 0,
      default: Prefab::VariantDistribution.new(variant_weights:
                                                 Prefab::VariantWeights.new(weights: [
                                                   Prefab::VariantWeight.new(weight: 500,
                                                                             variant_idx: 1),
                                                   Prefab::VariantWeight.new(weight: 500,
                                                                             variant_idx: 0),
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
      variants: [
        Prefab::FeatureFlagVariant.new(bool: false),
        Prefab::FeatureFlagVariant.new(bool: true)
      ],
      inactive_variant_idx: 0,
      default: Prefab::VariantDistribution.new(variant_idx: 1)
    )
    assert_equal true,
                 @client.is_on?(feature, "hashes high", [], flag)
    assert_equal true,
                 @client.is_on?(feature, "hashes low", [], flag)

    flag = Prefab::FeatureFlag.new(
      active: false,
      variants: [
        Prefab::FeatureFlagVariant.new(bool: false),
        Prefab::FeatureFlagVariant.new(bool: true)
      ],
      inactive_variant_idx: 0,
      default: Prefab::VariantDistribution.new(variant_idx: 1)
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
      variants: [
        Prefab::FeatureFlagVariant.new(string: "inactive"),
        Prefab::FeatureFlagVariant.new(string: "user target"),
        Prefab::FeatureFlagVariant.new(string: "default"),
      ],
      inactive_variant_idx: 0,
      user_targets: [
        variant_idx: 1,
        identifiers: ["user:1", "user:3"]
      ],
      default: Prefab::VariantDistribution.new(variant_idx: 2)
    )

    assert_equal "user target",
                 @client.get(feature, "user:1", [], flag)
    assert_equal "default",
                 @client.get(feature, "user:2", [], flag)
    assert_equal "user target",
                 @client.get(feature, "user:3", [], flag)
  end
end
