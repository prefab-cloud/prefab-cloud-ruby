# frozen_string_literal: true

module Prefab
  class JavaScriptStub
    LOG = Prefab::InternalLogger.new(self)

    def initialize(client = nil)
      @client = client || Prefab.instance
    end

    # Generate the JavaScript snippet to bootstrap the client SDK. This will
    # include the configuration values that are permitted to be sent to the
    # client SDK.
    #
    # If the context provided to the client SDK is not the same as the context
    # used to generate the configuration values, the client SDK will still
    # generate a fetch to get the correct values for the context.
    #
    # Any keys that could not be resolved will be logged as a warning to the
    # console.
    def bootstrap(context)
      configs, warnings = data(context)
      <<~JS
        window._prefabBootstrap = {
          configs: #{JSON.dump(configs)},
          context: #{JSON.dump(context)}
        }
        #{log_warnings(warnings)}
      JS
    end

    # Generate the JavaScript snippet to *replace* the client SDK. Use this to
    # get `prefab.get` and `prefab.isEnabled` functions on the window object.
    #
    # Only use this if you are not using the client SDK and do not need
    # client-side context.
    #
    # Any keys that could not be resolved will be logged as a warning to the
    # console.
    def generate_stub(context)
      configs, warnings = data(context)
      <<~JS
        window.prefab = window.prefab || {};
        window.prefab.config = #{JSON.dump(configs)};
        window.prefab.get = function(key) {
          return window.prefab.config[key];
        };
        window.prefab.isEnabled = function(key) {
          return window.prefab.config[key] === true;
        };
        #{log_warnings(warnings)}
      JS
    end

    private

    def underlying_value(value)
      v = Prefab::ConfigValueUnwrapper.new(value, @client.resolver).unwrap
      case v
      when Google::Protobuf::RepeatedField
        v.to_a
      when Prefab::Duration
        v.as_json
      else
        v
      end
    end

    def log_warnings(warnings)
      return '' if warnings.empty?

      <<~JS
        console.warn('The following keys could not be resolved:', #{JSON.dump(@warnings)});
      JS
    end

    def data(context)
      permitted = {}
      warnings = []
      resolver_keys = @client.resolver.keys

      resolver_keys.each do |key|
        begin
          config = @client.resolver.raw(key)

          if config.config_type == :FEATURE_FLAG || config.send_to_client_sdk
            permitted[key] = underlying_value(@client.resolver.get(key, context).value)
          end
        rescue StandardError => e
          LOG.warn("Could not resolve key #{key}: #{e}")

          warnings << key
        end
      end

      [permitted, warnings]
    end
  end
end
