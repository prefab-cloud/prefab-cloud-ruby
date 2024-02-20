# frozen_string_literal: true

module Prefab
  class LoggerClient
    SEP = '.'
    BASE_KEY = 'log-level'
    NO_DEFAULT = nil

    LOG_LEVEL_LOOKUPS = {
      PrefabProto::LogLevel::NOT_SET_LOG_LEVEL => :trace,
      PrefabProto::LogLevel::TRACE => :trace,
      PrefabProto::LogLevel::DEBUG => :debug,
      PrefabProto::LogLevel::INFO => :info,
      PrefabProto::LogLevel::WARN => :warn,
      PrefabProto::LogLevel::ERROR => :error,
      PrefabProto::LogLevel::FATAL => :fatal
    }.freeze

    def initialize(client: ,log_path_aggregator: )
      @config_client = client
      @log_path_aggregator = log_path_aggregator
    end

    def should_log?(severity, path)
      @log_path_aggregator&.push(path, severity)
      severity >= level_of(path)
    end

    def semantic_filter(log)
      class_path = class_path_name(log.name)
      lookup_path = "#{logger_prefix}.#{class_path}"
      level = SemanticLogger::Levels.index(log.level)
      log.named_tags.merge!({ path: lookup_path })
      should_log? level, lookup_path
    end


    def config_client=(config_client)
      @config_client = config_client
    end

    private

    def class_path_name(class_name)
      log_class = Logger.const_get(class_name)
      if log_class.respond_to?(:superclass) && log_class.superclass != Object
        underscore("#{log_class.superclass.name}.#{log_class.name}")
      else
        underscore("#{log_class.name}")
      end.gsub(/[^a-z_]/i, '.')
    end

    def logger_prefix
      Context.current.get("application.key") ||  "prefab-cloud-ruby"
    end

    # Find the closest match to 'log_level.path' in config
    def level_of(path)
      closest_log_level_match = nil

      path.split(SEP).each_with_object([BASE_KEY]) do |n, memo|
        memo << n
        val = @config_client.get(memo.join(SEP), NO_DEFAULT)
        closest_log_level_match = val unless val.nil?
      end

      if closest_log_level_match.nil?
        # get the top-level setting or default to WARN
        closest_log_level_match = @config_client.get(BASE_KEY, :WARN)
      end

      closest_log_level_match_int = PrefabProto::LogLevel.resolve(closest_log_level_match)
      internal_convert = LOG_LEVEL_LOOKUPS[closest_log_level_match_int]
      return SemanticLogger::Levels.index(internal_convert)
    end

    def underscore(string)
      string.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end
