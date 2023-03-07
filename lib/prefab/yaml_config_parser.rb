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
        @client.log_internal ::Logger::INFO, "Load #{@file}"
        YAML.load_file(@file)
      else
        @client.log_internal ::Logger::INFO, "No file #{@file}"
        {}
      end
    end
  end
end
