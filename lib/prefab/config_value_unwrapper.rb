# frozen_string_literal: true

module Prefab
  class ConfigValueUnwrapper
    LOG = Prefab::InternalLogger.new(ConfigValueUnwrapper)
    attr_reader :value, :weighted_value_index

    def initialize(value, resolver, weighted_value_index = nil)
      @value = value
      @resolver = resolver
      @weighted_value_index = weighted_value_index
    end

    def unwrap
      raw = case value.type
            when :int, :string, :double, :bool, :log_level
              value.public_send(value.type)
            when :string_list
              value.string_list.values
            else
              LOG.error "Unknown type: #{config_value.type}"
              raise "Unknown type: #{config_value.type}"
            end
      if value.has_decrypt_with?
        descyrption_key = @resolver.get(value.decrypt_with).unwrapped_value
        unencrypted = Prefab::Encryption.new(descyrption_key).decrypt(raw)
        return unencrypted
      else
        raw
      end
    end

    def self.deepest_value(config_value, config_key, context, resolver=NoopResolver.new)
      if config_value&.type == :weighted_values
        value, index = Prefab::WeightedValueResolver.new(
          config_value.weighted_values.weighted_values,
          config_key,
          context.get(config_value.weighted_values.hash_by_property_name)
        ).resolve

        new(deepest_value(value.value, config_key, context, resolver).value, resolver, index)

      elsif config_value&.type == :provided
        if :ENV_VAR == config_value.provided.source
          raw = ENV[config_value.provided.lookup]
          puts "LOOKUP ENV #{config_value.provided.lookup} got #{raw}"
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
