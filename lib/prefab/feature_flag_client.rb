# frozen_string_literal: true

module Prefab
  class FeatureFlagClient
    def initialize(base_client)
      @base_client = base_client
    end

    def feature_is_on?(feature_name)
      feature_is_on_for?(feature_name, nil)
    end

    def feature_is_on_for?(feature_name, lookup_key, attributes: {})
      @base_client.stats.increment('prefab.featureflag.on', tags: ["feature:#{feature_name}"])

      variant = @base_client.config_client.get(feature_name, false, attributes, lookup_key)

      is_on?(variant)
    end

    def get(feature_name, lookup_key = nil, attributes = {}, default: false)
      value = _get(feature_name, lookup_key, attributes)

      value.nil? ? default : value
    end

    private

    def _get(feature_name, lookup_key = nil, attributes = {})
      @base_client.config_client.get(feature_name, nil, attributes, lookup_key)
    end

    def is_on?(variant)
      return false if variant.nil?

      return variant if variant == !!variant

      variant.bool
    rescue StandardError
      @base_client.log.info("is_on? methods only work for boolean feature flags variants. This feature flags variant is '#{variant}'. Returning false")
      false
    end
  end
end
