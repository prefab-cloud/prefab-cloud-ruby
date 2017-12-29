require 'yaml'
module EzConfig
  class ConfigLoader
    def initialize(logger)
      @logger = logger
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

    def set(delta)
      @api_config[delta.key] = delta.value
    end

    private

    def load_classpath_config
      load_glob(".prefab*config.yaml")
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
        @logger.info "No file #{filename}"
        {}
      end
    end

    def value_from(raw)
      case raw
      when String
        {string: raw}
      when Integer
        {int: raw}
      when TrueClass, FalseClass
        {bool: raw}
      when Float
        {double: raw}
      end
    end
  end
end
