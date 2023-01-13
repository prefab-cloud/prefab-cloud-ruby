# frozen_string_literal: true

module Prefab
  class FeatureFlagClient
    include Prefab::ConfigHelper
    MAX_32_FLOAT = 4294967294.0

    def initialize(base_client)
      @base_client = base_client
    end

    def upsert(feature_name, feature_obj)
      @base_client.config_client.upsert(feature_name, Prefab::ConfigValue.new(feature_flag: feature_obj))
    end

    def feature_is_on?(feature_name)
      feature_is_on_for?(feature_name, nil)
    end

    def feature_is_on_for?(feature_name, lookup_key, attributes: {})
      @base_client.stats.increment("prefab.featureflag.on", tags: ["feature:#{feature_name}"])

      return is_on?(_get(feature_name, lookup_key, attributes, default: false))
    end

    def get(feature_name, lookup_key = nil, attributes = {}, default: false)
      variant = _get(feature_name, lookup_key, attributes, default: default)

      value_of_variant_or_nil(variant, default)
    end

    private

    def value_of_variant_or_nil(variant_maybe, default)
      if variant_maybe.nil?
        default != Prefab::Client::NO_DEFAULT_PROVIDED ? default : nil
      else
        value_of_variant(variant_maybe)
      end
    end

    def _get(feature_name, lookup_key = nil, attributes = {}, default:)
      feature_obj = @base_client.config_client.get(feature_name, default)
      config_obj = @base_client.config_client.get_config_obj(feature_name)

      return nil if feature_obj.nil? || config_obj.nil?

      if feature_obj == !!feature_obj
        return feature_obj
      end

      variants = config_obj.variants
      get_variant(feature_name, lookup_key, attributes, feature_obj, variants)
    end

    def is_on?(variant)
      if variant.nil?
        return false
      end

      if variant == !!variant
        return variant
      end

      variant.bool
    rescue
      @base_client.log.info("is_on? methods only work for boolean feature flags variants. This feature flags variant is '#{variant}'. Returning false")
      false
    end

    def get_variant(feature_name, lookup_key, attributes, feature_obj, variants)
      if !feature_obj.active
        return get_variant_obj(variants, feature_obj.inactive_variant_idx)
      end

      # default to inactive
      variant_weights = [Prefab::VariantWeight.new(variant_idx: feature_obj.inactive_variant_idx, weight: 1)]

      # if rules.match
      feature_obj.rules.each do |rule|
        if criteria_match?(rule.criteria, lookup_key, attributes)
          variant_weights = rule.variant_weights
          break
        end
      end

      percent_through_distribution = rand()
      if lookup_key
        percent_through_distribution = get_user_pct(feature_name, lookup_key)
      end

      variant_idx = get_variant_idx_from_weights(variant_weights, percent_through_distribution, feature_name)

      return get_variant_obj(variants, variant_idx)
    end

    def get_variant_obj(variants, idx)
      # our array is 0 based, but the idx are 1 based so the protos are clearly set
      return variants[idx - 1] if variants.length >= idx

      nil
    end

    def get_variant_idx_from_weights(variant_weights, percent_through_distribution, feature_name)
      distrubution_space = variant_weights.inject(0) { |sum, v| sum + v.weight }
      bucket = distrubution_space * percent_through_distribution
      sum = 0
      variant_weights.each do |variant_weight|
        if bucket < sum + variant_weight.weight
          return variant_weight.variant_idx
        else
          sum += variant_weight.weight
        end
      end
      # variants didn't add up to 100%
      @base_client.log.info("Variants of #{feature_name} did not add to 100%")
      return variant_weights.last.variant_idx
    end

    def get_user_pct(feature, lookup_key)
      to_hash = "#{feature}#{lookup_key}"
      int_value = Murmur3.murmur3_32(to_hash)
      int_value / MAX_32_FLOAT
    end

    def criteria_match?(criteria, lookup_key, attributes)
      case criteria.operator
      when :ALWAYS_TRUE
        true
      when :LOOKUP_KEY_IN
        criteria.values.include?(lookup_key)
      when :LOOKUP_KEY_NOT_IN
        !criteria.values.include?(lookup_key)
      when :IN_SEG
        segment_matches?(criteria.values, lookup_key, attributes)
      when :NOT_IN_SEG
        !segment_matches?(criteria.values, lookup_key, attributes)
      when :PROP_IS_ONE_OF
        criteria.values.include?(attribute_value(attributes, criteria.property))
      when :PROP_IS_NOT_ONE_OF
        !criteria.values.include?(attribute_value(attributes, criteria.property))
      when :PROP_ENDS_WITH_ONE_OF
        criteria.values.any? { |value| attribute_value(attributes, criteria.property)&.end_with?(value) }
      when :PROP_DOES_NOT_END_WITH_ONE_OF
        criteria.values.none? { |value| attribute_value(attributes, criteria.property)&.end_with?(value) }
      else
        @base_client.log.info("Unknown Operator: #{criteria.operator}")
        false
      end
    end

    def attribute_value(attributes, property)
      attributes[property] || attributes[property.to_sym]
    end

    # evaluate each segment key and return whether any match
    # there should be an associated segment available as a standard config obj
    def segment_matches?(segment_keys, lookup_key, attributes)
      segment_keys.any? do |segment_key|
        segment = @base_client.config_client.get(segment_key)
        if segment.nil?
          @base_client.log.info("Missing Segment")
          false
        else
          segment_match?(segment, lookup_key, attributes)
        end
      end
    end

    # does a given segment match?
    def segment_match?(segment, lookup_key, attributes)
      segment.criterion.any? do |criteria|
        criteria_match?(criteria, lookup_key, attributes)
      end
    end
  end
end
