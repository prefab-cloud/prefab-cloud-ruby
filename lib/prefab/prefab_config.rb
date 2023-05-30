module Prefab
  class Feature123

    TREATMENT = 'treatment'
    CONTROL = 'control'

    def value
      CONTROL
    end
  end
  class Config
    class << self
      def feature_123
        config_client.get("feature_123", false)
      end

    end
  end
end

f = PrefabConfig.feature_123

PrefabConfig
