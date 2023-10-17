require 'yaml'

module Prefab
  class YAMLConfigParser
    def initialize(file, client)
      @file = file
      @client = client
    end

    def merge(config)
      yaml = load

      yaml.each do |k, v|
        config = Prefab::LocalConfigParser.parse(k, v, config, @file)
      end

      config
    end

    private

    def load
      if File.exist?(@file)
        Prefab.internal_logger.info "Load #{@file}"
        YAML.load_file(@file)
      else
        Prefab.internal_logger.info "No file #{@file}"
        {}
      end
    end
  end
end
