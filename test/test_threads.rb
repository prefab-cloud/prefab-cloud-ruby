# frozen_string_literal: true
require 'test_helper'

class TestThreads < Minitest::Test

  def setup
    super
    @mock_base_client = MockBaseClient.new
    @client = Prefab::FeatureFlagClient.new(@mock_base_client)
  end

  def test_threaded
    segment_key_one = "prefab-segment-segment-1"
    @mock_base_client.config_client.mock_this_config(segment_key_one,
                                                     Prefab::Segment.new(
                                                       criterion: [
                                                         Prefab::Criteria.new(
                                                           operator: Prefab::Criteria::CriteriaOperator::LOOKUP_KEY_IN,
                                                           values: ["user:1", "user:2"]
                                                         )
                                                       ]
                                                     )
    )
    feature_flag = "feature_flag"
    variants = [
      Prefab::FeatureFlagVariant.new(string: "inactive"),
      Prefab::FeatureFlagVariant.new(string: "rule target"),
      Prefab::FeatureFlagVariant.new(string: "default"),
    ]
    flag = Prefab::FeatureFlag.new(
      active: true,
      inactive_variant_idx: 1,
      rules: [
        Prefab::Rule.new(
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 2)
          ],
          criteria: Prefab::Criteria.new(
            operator: "IN_SEG",
            values: ["prefab-segment-segment-1"]
          )
        ),
        Prefab::Rule.new(
          criteria: Prefab::Criteria.new(operator: Prefab::Criteria::CriteriaOperator::ALWAYS_TRUE),
          variant_weights: [
            Prefab::VariantWeight.new(weight: 1000,
                                      variant_idx: 3)
          ]
        )

      ],
    )
    @mock_base_client.config_client.mock_this_config(feature_flag, flag, variants)

    threads = []
    (1..50).each do |i|
      threads << Thread.new do
        (1..100000).each do |iter|
          assert_equal "rule target", @client.get(feature_flag, "user:1")
          puts "assert #{i} #{iter}"
        end
      end
    end

    threads.map(&:join)
  end

  def evaluate(feature_name, lookup_key, attributes, flag, variants)
    variant = @client.get_variant(feature_name, lookup_key, attributes, flag, variants)
    @client.value_of_variant(variant)
  end
end
