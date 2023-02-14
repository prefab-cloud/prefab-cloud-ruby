# frozen_string_literal: true

require 'test_helper'

class TestThreads < Minitest::Test
  PROJECT_ENV_ID = 1

  def setup
    super
    @mock_base_client = MockBaseClient.new
    @client = Prefab::FeatureFlagClient.new(@mock_base_client)
  end

  def test_threaded
    segment_key_one = 'prefab-segment-segment-1'

    segment_config = Prefab::Config.new(
      config_type: Prefab::ConfigType::SEGMENT,
      key: segment_key_one,
      rows: [
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_ENDS_WITH_ONE_OF,
                  value_to_match: string_list(['prefab.cloud', 'gmail.com']),
                  property_name: 'email'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: true),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::PROP_IS_ONE_OF,
                  value_to_match: Prefab::ConfigValue.new(bool: true),
                  property_name: 'admin'
                )
              ]
            ),
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(bool: false)
            )
          ]
        )
      ]
    )

    @mock_base_client.config_client.mock_this_config(segment_key_one, segment_config)

    feature_flag = 'feature_flag'
    variants = [
      Prefab::ConfigValue.new(string: 'inactive'),
      Prefab::ConfigValue.new(string: 'rule target'),
      Prefab::ConfigValue.new(string: 'default')
    ]
    flag = Prefab::Config.new(
      key: feature_flag,
      config_type: Prefab::ConfigType::FEATURE_FLAG,
      rows: [
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              value: Prefab::ConfigValue.new(weighted_values: weighted_values([['rule target', 1000]])),
              criteria: [
                Prefab::Criterion.new(
                  operator: Prefab::Criterion::CriterionOperator::IN_SEG,
                  value_to_match: Prefab::ConfigValue.new(string: segment_key_one)
                )
              ]
            )
          ]
        ),
        Prefab::ConfigRow.new(
          project_env_id: PROJECT_ENV_ID,
          values: [
            Prefab::ConditionalValue.new(
              criteria: [Prefab::Criterion.new(operator: Prefab::Criterion::CriterionOperator::ALWAYS_TRUE)],
              value: Prefab::ConfigValue.new(weighted_values: weighted_values([['default', 1000]]))
            )
          ]
        )
      ]
    )
    @mock_base_client.config_client.mock_this_config(feature_flag, flag, variants)

    threads = []
    (1..50).each do |i|
      threads << Thread.new do
        (1..100_000).each do |iter|
          assert_equal feature_flag, @client.get(feature_flag, 'user:1', {}, default: false).key
          puts "assert #{i} #{iter}"
        end
      end
    end

    threads.map(&:join)
  end

  private

  def string_list(values)
    Prefab::ConfigValue.new(string_list: Prefab::StringList.new(values: values))
  end

  def weighted_values(values_and_weights)
    values = values_and_weights.map do |value, weight|
      weighted_value(value, weight)
    end

    Prefab::WeightedValues.new(weighted_values: values)
  end

  def weighted_value(string, weight)
    Prefab::WeightedValue.new(
      value: Prefab::ConfigValue.new(string: string), weight: weight
    )
  end
end
