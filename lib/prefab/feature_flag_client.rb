module Prefab
  class FeatureFlagClient
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

    def feature_is_on_for?(feature_name, lookup_key, attributes: [])
      @base_client.stats.increment("prefab.featureflag.on", tags: ["feature:#{feature_name}"])

      feature_obj = @base_client.config_client.get(feature_name)
      return is_on?(feature_name, lookup_key, attributes, feature_obj)
    end

    private

    def is_on?(feature_name, lookup_key, attributes, feature_obj)
      if feature_obj.nil?
        return false
      end

      attributes << lookup_key if lookup_key
      if (attributes & feature_obj.whitelisted).size > 0
        return true
      end

      if lookup_key
        return get_user_pct(feature_name, lookup_key) < feature_obj.pct
      end

      return feature_obj.pct > rand()
    end

    def get_user_pct(feature, lookup_key)
      to_hash = "#{@base_client.account_id}#{feature}#{lookup_key}"
      int_value = Murmur3.murmur3_32(to_hash)
      int_value / MAX_32_FLOAT
    end

  end
end

