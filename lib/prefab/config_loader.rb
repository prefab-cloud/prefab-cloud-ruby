require 'yaml'
module Prefab
  class ConfigLoader
    def initialize(base_client)
      @base_client = base_client
      @classpath_config = load_classpath_config
      @local_overrides = load_local_overrides
      @api_config = Concurrent::Map.new
    end

    def calc_config
      rtn = @classpath_config.clone
      @api_config.each_key do |k|
        rtn[k] = @api_config[k].value
      end
      rtn = rtn.merge(@local_overrides)
      rtn
    end

    def set(delta)
      if delta.value.nil?
        @api_config.delete(delta.key)
      else
        @api_config[delta.key] = delta
      end
    end

    def rm(key)
      @api_config.delete key
    end

    def get_api_deltas
      deltas = Prefab::ConfigDeltas.new
      @api_config.each_value do |config_value|
        deltas.deltas << config_value
      end
      deltas
    end

    private

    def load_classpath_config
      classpath_dir = ENV['PREFAB_CONFIG_CLASSPATH_DIR'] || ""
      load_glob(File.join(classpath_dir, ".prefab*config.yaml"))
    end

    def load_local_overrides
      override_dir = ENV['PREFAB_CONFIG_OVERRIDE_DIR'] || Dir.home
      load_glob(File.join(override_dir, ".prefab*config.yaml"))
    end

    def load_glob(glob)
      rtn = {}
      Dir.glob(glob).each do |file|
        yaml = load(file)
        yaml.each do |k, v|
          rtn[k] = Prefab::ConfigValue.new(value_from(v))
        end
      end
      rtn
    end

    def load(filename)
      if File.exist? filename
        YAML.load_file(filename)
      else
        @base_client.logger.info "No file #{filename}"
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
  end
end
