module Prefab
  module Feature123
    class Treatment
    end
    class Control
    end
    def value_of(value)
      Prefab::Feature123::Control.new if value == CONTROL
      Prefab::Feature123::Treatment.new if value == TREATMENT
    end
  end
  class Config
    class << self
      def feature_123
        value_of(config_client.get("feature_123"))
      end
      def feature_123_is_treatment?
        feature_123 == Prefab::Feature123::TREATMENT
      end
      def feature_123_is_control?
        feature_123 == Prefab::Feature123::Control
      end
      def feature_bool?
        config_client.get_bool("feature_bool")
      end
      def http_timeout
        config_client.get_int("http_timeout")
      end
      def http_retries
        config_client.get_int("http_retries")
      end
      def db_host
        config_client.get_string("db_host")
      end
    end
  end
end

f = PrefabConfig.feature_123 == Prefab::Feature123::TREATMENT

PrefabConfig.class
