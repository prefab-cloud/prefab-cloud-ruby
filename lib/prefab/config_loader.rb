require 'yaml'
module EzConfig
  class ConfigLoader



    def initialize()
      load_ez_config
      load_project_config
      load_local_overrides
      @api_config = Concurrent::Map.new
      @immutable_config = @ez_config.merge(@project_config)

      # puts @ez_config
      # puts @project_config
      # puts @api_config
      # puts @local_overrides
      # puts "---"
      # # puts .merge(@api_config).merge(@local_overrides)
      # puts calc_config
    end

    def calc_config
      rtn = @immutable_config.clone
      @api_config.each_key do |k|
        puts "api set #{k} tp #{@api_config[k]}"
        rtn[k] = @api_config[k]
      end
      rtn = rtn.merge(@local_overrides)
puts rtn
      rtn
      # @immutable_config.merge(@api_config).merge(@local_overrides)
    end

    def set(delta)
      puts "setting"
      @api_config[delta.key] = delta.value.string
    end

    private

    def load_ez_config
      @ez_config = YAML.load_file(".ezconfig.yaml")
    end

    def load_project_config
      @project_config = YAML.load_file(".projectconfig.yaml")
    end

    def load_local_overrides
      @local_overrides = YAML.load_file(".ezconfig.overrides.yaml")
    end

  end
end
