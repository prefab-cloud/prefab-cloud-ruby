# frozen_string_literal: true

require 'yaml'
module Prefab
  class ConfigLoader
    attr_reader :highwater_mark

    def initialize(base_client)
      @base_client = base_client
      @prefab_options = base_client.options
      @highwater_mark = 0
      @classpath_config = load_classpath_config
      @local_overrides = load_local_overrides
      @api_config = Concurrent::Map.new
    end

    def calc_config
      rtn = @classpath_config.clone
      @api_config.each_key do |k|
        rtn[k] = @api_config[k]
      end
      rtn = rtn.merge(@local_overrides)
      rtn
    end

    def set(config, source)
      # don't overwrite newer values
      if @api_config[config.key] && @api_config[config.key][:config].id >= config.id
        return
      end

      if config.rows.empty?
        @api_config.delete(config.key)
      else
        if @api_config[config.key]
          @base_client.log_internal Logger::DEBUG, "Replace #{config.key} with value from #{source} #{ @api_config[config.key][:config].id} -> #{config.id}"
        end
        @api_config[config.key] = { source: source, config: config }
      end
      @highwater_mark = [config.id, @highwater_mark].max
    end

    def rm(key)
      @api_config.delete key
    end

    def get_api_deltas
      configs = Prefab::Configs.new
      @api_config.each_value do |config_value|
        configs.configs << config_value[:config]
      end
      configs
    end

    private

    def load_classpath_config
      classpath_dir = @prefab_options.prefab_config_classpath_dir
      load_glob(File.join(classpath_dir, ".prefab*config.yaml"))
    end

    def load_local_overrides
      override_dir = @prefab_options.prefab_config_override_dir
      load_glob(File.join(override_dir, ".prefab*config.yaml"))
    end

    def load_glob(glob)
      rtn = {}
      Dir.glob(glob).each do |file|
        yaml = load(file)
        yaml.each do |k, v|
          if v.class == Hash
            v.each do |env_k, env_v|
              if k == @prefab_options.defaults_env
                if env_v.class == Hash && env_v['feature_flag']
                  rtn[env_k] = feature_flag_config(file, k, env_k, env_v)
                else
                  rtn[env_k] = {
                    source: file,
                    match: k,
                    config: Prefab::Config.new(
                      key: env_k,
                      rows: [
                        Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(value_from(env_v)))
                      ]
                    )
                  }
                end
              else
                next
              end
            end
          else
            rtn[k] = {
              source: file,
              match: "default",
              config: Prefab::Config.new(
                key: k,
                rows: [
                  Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(value_from(v)))
                ]
              )
            }
          end
        end
      end
      rtn
    end

    def load(filename)
      if File.exist? filename
        @base_client.log_internal Logger::INFO, "Load #{filename}"
        YAML.load_file(filename)
      else
        @base_client.log_internal Logger::INFO, "No file #{filename}"
        {}
      end
    end

    def value_from(raw)
      case raw
      when String
        { string: raw }
      when Integer
        { int: raw }
      when TrueClass, FalseClass
        { bool: raw }
      when Float
        { double: raw }
      end
    end

    def feature_flag_config(file, k, env_k, env_v)
      criteria = Prefab::Criteria.new(operator: 'ALWAYS_TRUE')

      if env_v['criteria']
        criteria = Prefab::Criteria.new(criteria_values(env_v['criteria']))
      end

      row = Prefab::ConfigRow.new(
        value: Prefab::ConfigValue.new(
          feature_flag: Prefab::FeatureFlag.new(
            active: true,
            inactive_variant_idx: -1, # not supported
            rules: [
              Prefab::Rule.new(
                variant_weights: [
                  Prefab::VariantWeight.new(variant_idx: 0, weight: 1000)
                ],
                criteria: criteria
              )
            ]
          )
        )
      )

      unless env_v.has_key?('value')
        raise Prefab::Error, "Feature flag config `#{env_k}` #{file} must have a `value`"
      end

      {
        source: file,
        match: k,
        config: Prefab::Config.new(
          key: env_k,
          variants: [Prefab::FeatureFlagVariant.new(value_from(env_v['value']))],
          rows: [row]
        )
      }
    end

    def criteria_values(criteria_hash)
      if RUBY_VERSION < '2.7'
        criteria_hash.transform_keys(&:to_sym)
      else
        criteria_hash
      end
    end
  end
end
