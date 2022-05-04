module Prefab
  class FeatureFlagClient
    include Prefab::ConfigHelper
    MAX_32_FLOAT = 4294967294.0
    DISTRIBUTION_SPACE = 1000

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

      return is_on?(get(feature_name, lookup_key, attributes))
    end

    def get(feature_name, lookup_key=nil, attributes={})
      feature_obj = @base_client.config_client.get(feature_name)
      variants = @base_client.config_client.get_config_obj(feature_name).variants
      evaluate(feature_name, lookup_key, attributes, feature_obj, variants)
    end

    def evaluate(feature_name, lookup_key, attributes, feature_obj, variants)
      value_of(get_variant(feature_name, lookup_key, attributes, feature_obj, variants))
    end

    private

    def is_on?(variant)
      if variant.nil?
        return false
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

      # if user_targets.match
      feature_obj.user_targets.each do |target|
        if (target.identifiers.include? lookup_key)
          return get_variant_obj(variants, target.variant_idx)
        end
      end

      #default to inactive
      variant_weights = [Prefab::VariantWeight.new(variant_idx: feature_obj.inactive_variant_idx, weight: 1)]

      # if rules.match
      feature_obj.rules.each do |rule|
        if criteria_match?(rule, lookup_key, attributes)
          variant_weights = rule.variant_weights
          break
        end
      end


      percent_through_distribution = rand()
      if lookup_key
        percent_through_distribution = get_user_pct(feature_name, lookup_key)
      end
      distribution_bucket = DISTRIBUTION_SPACE * percent_through_distribution

      variant_idx = get_variant_idx_from_weights(variant_weights, distribution_bucket, feature_name)

      return get_variant_obj(variants, variant_idx)
    end

    def get_variant_obj(variants, idx)
      # our array is 0 based, but the idx are 1 based so the protos are clearly set
      return variants[idx - 1] if variants.length >= idx
      nil
    end

    def get_variant_idx_from_weights(variant_weights, bucket, feature_name)
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
      to_hash = "#{@base_client.project_id}#{feature}#{lookup_key}"
      int_value = Murmur3.murmur3_32(to_hash)
      int_value / MAX_32_FLOAT
    end

    def criteria_match?(rule, lookup_key, attributes)

      if rule.criteria.operator == :ALWAYS_TRUE
        return true
      elsif rule.criteria.operator == :LOOKUP_KEY_IN
        return rule.criteria.values.include?(lookup_key)
      elsif rule.criteria.operator == :LOOKUP_KEY_NOT_IN
        return !rule.criteria.values.include?(lookup_key)
      elsif rule.criteria.operator == :IN_SEG
        return segment_matches(rule.criteria.values, lookup_key, attributes).any?
      elsif rule.criteria.operator == :NOT_IN_SEG
        return segment_matches(rule.criteria.values, lookup_key, attributes).none?
      elsif rule.criteria.operator == :PROP_IS_ONE_OF
        return rule.criteria.values.include?(attributes[rule.criteria.property]) || rule.criteria.values.include?(attributes[rule.criteria.property.to_sym])
      elsif rule.criteria.operator == :PROP_IS_NOT_ONE_OF
        return !(rule.criteria.values.include?(attributes[rule.criteria.property]) || rule.criteria.values.include?(attributes[rule.criteria.property.to_sym]))
      end
      @base_client.log.info("Unknown Operator")
      false
    end

    # evaluate each segment key and return whether each one matches
    # there should be an associated segment available as a standard config obj
    def segment_matches(segment_keys, lookup_key, attributes)
      segment_keys.map do |segment_key|
        segment = @base_client.config_client.get(segment_key)
        if segment.nil?
          @base_client.log.info("Missing Segment")
          false
        else
          segment_match?(segment, lookup_key, attributes)
        end
      end
    end

    def segment_match?(segment, lookup_key, attributes)
      includes = segment.includes.include?(lookup_key)
      excludes = segment.excludes.include?(lookup_key)
      includes && !excludes
    end
  end
end

