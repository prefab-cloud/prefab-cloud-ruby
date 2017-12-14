require 'yaml'
module EzConfig
  class ConfigLoader
    def initialize(logger)
      @logger = logger
      load_ez_config
      load_project_config
      load_local_overrides
      @api_config = Concurrent::Map.new
      @immutable_config = @ez_config.merge(@project_config)
    end

    def calc_config
      rtn = @immutable_config.clone
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

    def load_ez_config
      @ez_config = load(".ezconfig.yaml")
    end

    def load_project_config
      @project_config = load(".projectconfig.yaml")
    end

    def load_local_overrides
      @local_overrides = load(".ezconfig.overrides.yaml")
    end

    def load(filename)
      if File.exist? filename

        YAML.load_file(filename)
      else
        @logger.info "No file #{filename}"
        {}
      end
    end

  end
end
