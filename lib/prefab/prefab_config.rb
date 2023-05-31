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
    UNSET = Prefab::Context.new
    class << self
      def feature_123(context = UNSET, default = nil)
        value_of(config_client.get("feature_123"), context, default)
      end
      def feature_123_is_treatment?(context = UNSET, default = nil)
        feature_123(context, default).class == Prefab::Feature123::TREATMENT
      end
      def feature_123_is_control?(context = UNSET, default = nil)
        feature_123(context, default).class == Prefab::Feature123::Control
      end
      def feature_bool?(context = UNSET, default = nil)
        config_client.get_bool("feature_bool", context, default)
      end
      def http_timeout(context = UNSET, default = nil)
        config_client.get_int("http_timeout", context, default)
      end
      def http_retries(context = UNSET, default = nil)
        config_client.get_int("http_retries", context, default)
      end
      def db_host(context = UNSET, default = nil)
        config_client.get_string("db_host", context, default)
      end
    end
  end
end

class Usage
  def my_method
    if Prefab::Config.feature_123_is_treatment?
      # do treatment
    elsif Prefab::Config.feature_123_is_control?
      # do control
    end

    if Prefab::Config.feature_bool?(Prefab::Context.new({ user: {runtime: 123}}))
      # do feature bool for runtime property 123
    end

    HttpConnection.new(timeout: Prefab::Config.http_timeout, retries: Prefab::Config.http_retries)


    puts "DB connection is #{Prefab::Config.db_host(Prefab::Config::UNSET, "localhost")}"
  end
end
