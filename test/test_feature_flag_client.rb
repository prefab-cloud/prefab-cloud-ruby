require 'test_helper'

class TestFeatureFlagClient < Minitest::Test

  def setup
    super
    @mock_base_client = MockBaseClient.new
    @client = Prefab::FeatureFlagClient.new(@mock_base_client)
    Prefab::FeatureFlagClient.send(:public, :is_on?) #publicize for testing
    Prefab::FeatureFlagClient.send(:public, :segment_match?) #publicize for testing
  end

  def test_pct
    feature = "FlagName"

    variants = [
      Prefab::FeatureFlagVariant.new(bool: false),
      Prefab::FeatureFlagVariant.new(bool: true)
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      rules: [
        Prefab::Rule.new(
          criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
          variant_weights: [
            Prefab::VariantWeight.new(weight: 500,
                                      variant_idx: 1),
            Prefab::VariantWeight.new(weight: 500,
                                      variant_idx: 0),
          ]
        )
      ]
    )

    assert_equal false,
                 @client.evaluate(feature, "hashes high", [], flag, variants)
    assert_equal true,
                 @client.evaluate(feature, "hashes low", [], flag, variants)
  end

  def test_basic_active_inactive
    feature = "FlagName"
    variants = [
      Prefab::FeatureFlagVariant.new(bool: false),
      Prefab::FeatureFlagVariant.new(bool: true)
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      rules: default_ff_rule(1)
    )
    assert_equal true,
                 @client.evaluate(feature, "hashes high", [], flag, variants)
    assert_equal true,
                 @client.evaluate(feature, "hashes low", [], flag, variants)

    variants = [
      Prefab::FeatureFlagVariant.new(bool: false),
      Prefab::FeatureFlagVariant.new(bool: true)
    ]
    flag = Prefab::FeatureFlag.new(
      active: false,
      inactive_variant_idx: 0,
      rules: default_ff_rule(1)
    )
    assert_equal false,
                 @client.evaluate(feature, "hashes high", [], flag, variants)
    assert_equal false,
                 @client.evaluate(feature, "hashes low", [], flag, variants)
  end

  def test_user_targets

    feature = "FlagName"
    variants = [
      Prefab::FeatureFlagVariant.new(string: "inactive"),
      Prefab::FeatureFlagVariant.new(string: "user target"),
      Prefab::FeatureFlagVariant.new(string: "default"),
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      user_targets: [
        variant_idx: 1,
        identifiers: ["user:1", "user:3"]
      ],
      rules: default_ff_rule(2)
    )

    assert_equal "user target",
                 @client.evaluate(feature, "user:1", [], flag, variants)
    assert_equal "default",
                 @client.evaluate(feature, "user:2", [], flag, variants)
    assert_equal "user target",
                 @client.evaluate(feature, "user:3", [], flag, variants)
  end

  def test_inclusion_rule
    feature = "FlagName"
    variants = [
      Prefab::FeatureFlagVariant.new(string: "inactive"),
      Prefab::FeatureFlagVariant.new(string: "rule target"),
      Prefab::FeatureFlagVariant.new(string: "default"),
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      rules: [
        Prefab::Rule.new(
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 1)
          ],
          criteria: Prefab::Criteria.new(
            operator: "IN",
            values: ["user:1"]
          )
        ),
        Prefab::Rule.new(
          criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 2)
          ]
        )

      ],
    )

    assert_equal "rule target",
                 @client.evaluate(feature, "user:1", [], flag, variants)
    assert_equal "default",
                 @client.evaluate(feature, "user:2", [], flag, variants)

  end

  def test_segment_match?
    segment = Prefab::Segment.new(
      name: "Beta Group",
      includes: ["user:1", "user:5"],
      excludes: ["user:1", "user:2"]
    )
    assert_equal false, @client.segment_match?(segment, "user:0", {})
    assert_equal false, @client.segment_match?(segment, "user:1", {})
    assert_equal false, @client.segment_match?(segment, "user:2", {})
    assert_equal true, @client.segment_match?(segment, "user:5", {})
  end

  def test_segments
    segment_key = "prefab-segment-beta-group"
    @mock_base_client.config_client.mock_this_config(segment_key,
                                                     Prefab::Segment.new(
                                                       name: "Beta Group",
                                                       includes: ["user:1"]
                                                     )
    )

    feature = "FlagName"
    variants = [
      Prefab::FeatureFlagVariant.new(string: "inactive"),
      Prefab::FeatureFlagVariant.new(string: "rule target"),
      Prefab::FeatureFlagVariant.new(string: "default"),
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      rules: [
        Prefab::Rule.new(
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 1)
          ],
          criteria: Prefab::Criteria.new(
            operator: "IN_SEG",
            values: [segment_key]
          )
        ),
        Prefab::Rule.new(
          criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 2)
          ]
        )

      ],
    )

    assert_equal "rule target",
                 @client.evaluate(feature, "user:1", [], flag, variants)
    assert_equal "default",
                 @client.evaluate(feature, "user:2", [], flag, variants)

  end

  def test_in_multiple_segments_has_or_behavior
    segment_key_one = "prefab-segment-segment-1"
    @mock_base_client.config_client.mock_this_config(segment_key_one,
                                                     Prefab::Segment.new(
                                                       name: "Segment-1",
                                                       includes: ["user:1", "user:2"],
                                                       excludes: ["user:3"]
                                                     )
    )
    segment_key_two = "prefab-segment-segment-2"
    @mock_base_client.config_client.mock_this_config(segment_key_two,
                                                     Prefab::Segment.new(
                                                       name: "Segment-2",
                                                       includes: ["user:3", "user:4"],
                                                       excludes: ["user:2"]
                                                     )
    )

    feature = "FlagName"
    variants = [
      Prefab::FeatureFlagVariant.new(string: "inactive"),
      Prefab::FeatureFlagVariant.new(string: "rule target"),
      Prefab::FeatureFlagVariant.new(string: "default"),
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 0,
      rules: [
        Prefab::Rule.new(
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 1)
          ],
          criteria: Prefab::Criteria.new(
            operator: "IN_SEG",
            values: [segment_key_one, segment_key_two]
          )
        ),
        Prefab::Rule.new(
          criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 2)
          ]
        )
      ]
    )

    assert_equal "rule target",
                 @client.evaluate(feature, "user:1", [], flag, variants)
    assert_equal "rule target",
                 @client.evaluate(feature, "user:2", [], flag, variants), "matches segment 1"
    assert_equal "rule target",
                 @client.evaluate(feature, "user:3", [], flag, variants)
    assert_equal "rule target",
                 @client.evaluate(feature, "user:4", [], flag, variants)
    assert_equal "default",
                 @client.evaluate(feature, "user:5", [], flag, variants)

  end

end
