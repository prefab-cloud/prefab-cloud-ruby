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
        return feature_obj.inactive_value
      end

      variant_distribution = feature_obj.default

      # if user_targets.match
      feature_obj.user_targets.each do |target|
        if(target.identifiers.include? lookup_key)
          return target.variant
        end
      end

      # if rules.match
      # variant_distribution = rules...

      if variant_distribution.variant != nil
        return variant_distribution.variant
      else
        percent_through_distribution = rand()
        if lookup_key
          percent_through_distribution = get_user_pct(feature_name, lookup_key)
        end
        distribution_bucket = DISTRIBUTION_SPACE * percent_through_distribution

        return get_variant_from_weights(variant_distribution.variant_weights.weights, distribution_bucket)
      end
    end

    def get_variant_from_weights(variant_weights, bucket)
      sum = 0
      variant_weights.each do |variant_weight|
        if bucket < sum + variant_weight.weight
          return variant_weight.variant
        else
          sum += variant_weight.weight
        end
      end
      # variants didn't add up to 100%
      return variant_weights.last.variant
    end

    def get_user_pct(feature, lookup_key)
      to_hash = "#{@base_client.account_id}#{feature}#{lookup_key}"
      int_value = Murmur3.murmur3_32(to_hash)
      int_value / MAX_32_FLOAT
    end
  end
end

