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

    def feature_is_on_for?(feature_name, lookup_key, attributes: [])
      @base_client.stats.increment("prefab.featureflag.on", tags: ["feature:#{feature_name}"])

      feature_obj = @base_client.config_client.get(feature_name)
      return is_on?(feature_name, lookup_key, attributes, feature_obj)
    end

    def get(feature_name, lookup_key, attributes, feature_obj)
      value_of(get_variant(feature_name, lookup_key, attributes, feature_obj))
    end

    private

    def is_on?(feature_name, lookup_key, attributes, feature_obj)
      if feature_obj.nil?
        return false
      end

      get_variant(feature_name, lookup_key, attributes, feature_obj).bool
    end


    def get_variant(feature_name, lookup_key, attributes, feature_obj)
      if !feature_obj.active
        return get_variant_obj(feature_obj, feature_obj.inactive_variant_idx)
      end

      variant_distribution = feature_obj.default

      # if user_targets.match
      feature_obj.user_targets.each do |target|
        if(target.identifiers.include? lookup_key)
          return get_variant_obj(feature_obj, target.variant_idx)
        end
      end

      # if rules.match
      # variant_distribution = rules...
      # TODO

      if variant_distribution.type == :variant_idx
        variant_idx =  variant_distribution.variant_idx
      else
        percent_through_distribution = rand()
        if lookup_key
          percent_through_distribution = get_user_pct(feature_name, lookup_key)
        end
        distribution_bucket = DISTRIBUTION_SPACE * percent_through_distribution

        variant_idx = get_variant_idx_from_weights(variant_distribution.variant_weights.weights, distribution_bucket, feature_name)
      end

      return get_variant_obj(feature_obj, variant_idx)
    end

    def get_variant_obj(feature_obj, idx)
      return feature_obj.variants[idx] if feature_obj.variants.length >= idx
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
      return variant_weights.last.variant
    end

    def get_user_pct(feature, lookup_key)
      to_hash = "#{@base_client.account_id}#{feature}#{lookup_key}"
      int_value = Murmur3.murmur3_32(to_hash)
      int_value / MAX_32_FLOAT
    end
  end
end

