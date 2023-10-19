# frozen_string_literal: true

module Prefab
  class ConfigValueUnwrapper
    LOG = Prefab::InternalLogger.new(ConfigValueUnwrapper)
    CONFIDENTIAL_PREFIX = "*****"
    attr_reader :weighted_value_index

    def initialize(config_value, resolver, weighted_value_index = nil)
      @config_value = config_value
      @resolver = resolver
      @weighted_value_index = weighted_value_index
    end

    def reportable_wrapped_value
      if @config_value.confidential
        # Unique hash for differentiation
        Prefab::ConfigValueWrapper.wrap("#{CONFIDENTIAL_PREFIX}#{Digest::MD5.hexdigest(unwrap)[0,5]}")
      else
        @config_value
      end
    end

    def reportable_value
      Prefab::ConfigValueUnwrapper.new(reportable_wrapped_value, @resolver, @weighted_value_index).unwrap
    end

    def raw_config_value
      @config_value
    end

    # this will return the actual value of confidential, use reportable_value unless you need it
    def unwrap
      raw = case @config_value.type
            when :int, :string, :double, :bool, :log_level
              @config_value.public_send(@config_value.type)
            when :string_list
              @config_value.string_list.values
            else
              LOG.error "Unknown type: #{@config_value.type}"
              raise "Unknown type: #{@config_value.type}"
            end
      if @config_value.has_decrypt_with?
        decryption_key = @resolver.get(@config_value.decrypt_with).unwrapped_value
        unencrypted = Prefab::Encryption.new(decryption_key).decrypt(raw)
        return unencrypted
      end

      raw

    end

    def self.deepest_value(config_value, config_key, context, resolver=NoopResolver.new)
      if config_value&.type == :weighted_values
        value, index = Prefab::WeightedValueResolver.new(
          config_value.weighted_values.weighted_values,
          config_key,
          context.get(config_value.weighted_values.hash_by_property_name)
        ).resolve

        new(deepest_value(value.value, config_key, context, resolver).raw_config_value, resolver, index)

      elsif config_value&.type == :provided
        if :ENV_VAR == config_value.provided.source
          raw = ENV[config_value.provided.lookup]
          if raw.nil?
            LOG.warn "ENV Variable #{config_value.provided.lookup} not found. Using empty string."
            new(Prefab::ConfigValueWrapper.wrap(""), resolver)
          else
            new(Prefab::ConfigValueWrapper.wrap(YAML.load(raw)), resolver)
          end
        else
          raise "Unknown Provided Source #{config_value.provided.source}"
        end
      else
        new(config_value, resolver)
      end
    end
  end
  class NoopResolver
    def get(key)
      puts caller
      raise "This resolver should never be called"
    end
  end
end
