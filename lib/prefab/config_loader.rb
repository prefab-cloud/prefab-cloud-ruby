# frozen_string_literal: true

module Prefab
  class ConfigLoader
    LOG = Prefab::InternalLogger.new(ConfigLoader)

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
      rtn.merge(@local_overrides)
    end

    def set(config, source)
      # don't overwrite newer values
      return if @api_config[config.key] && @api_config[config.key][:config].id >= config.id

      if config.rows.empty?
        @api_config.delete(config.key)
      else
        if @api_config[config.key]
          LOG.debug(
                                    "Replace #{config.key} with value from #{source} #{@api_config[config.key][:config].id} -> #{config.id}")
        end
        @api_config[config.key] = { source: source, config: config }
      end
      @highwater_mark = [config.id, @highwater_mark].max
    end

    def rm(key)
      @api_config.delete key
    end

    def get_api_deltas
      configs = PrefabProto::Configs.new
      @api_config.each_value do |config_value|
        configs.configs << config_value[:config]
      end
      configs
    end

    private

    def load_classpath_config
      return {} if @prefab_options.datafile?
      classpath_dir = @prefab_options.prefab_config_classpath_dir
      rtn = load_glob(File.join(classpath_dir, '.prefab.default.config.yaml'))
      @prefab_options.prefab_envs.each do |env|
        rtn = rtn.merge load_glob(File.join(classpath_dir, ".prefab.#{env}.config.yaml"))
      end
      rtn
    end

    def load_local_overrides
      return {} if @prefab_options.datafile?
      override_dir = @prefab_options.prefab_config_override_dir
      rtn = load_glob(File.join(override_dir, '.prefab.default.config.yaml'))
      @prefab_options.prefab_envs.each do |env|
        rtn = rtn.merge load_glob(File.join(override_dir, ".prefab.#{env}.config.yaml"))
      end
      rtn
    end

    def load_glob(glob)
      rtn = {}
      Dir.glob(glob).each do |file|
        Prefab::YAMLConfigParser.new(file, @base_client).merge(rtn)
      end
      rtn
    end
  end
end
