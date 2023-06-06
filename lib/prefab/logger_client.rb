# frozen_string_literal: true

module Prefab
  class LoggerClient < ::Logger
    SEP = '.'
    BASE_KEY = 'log-level'
    UNKNOWN_PATH = 'unknown.'
    INTERNAL_PREFIX = 'cloud.prefab.client'

    LOG_LEVEL_LOOKUPS = {
      PrefabProto::LogLevel::NOT_SET_LOG_LEVEL => ::Logger::DEBUG,
      PrefabProto::LogLevel::TRACE => ::Logger::DEBUG,
      PrefabProto::LogLevel::DEBUG => ::Logger::DEBUG,
      PrefabProto::LogLevel::INFO => ::Logger::INFO,
      PrefabProto::LogLevel::WARN => ::Logger::WARN,
      PrefabProto::LogLevel::ERROR => ::Logger::ERROR,
      PrefabProto::LogLevel::FATAL => ::Logger::FATAL
    }

    def initialize(logdev, log_path_aggregator: nil, formatter: nil, prefix: nil)
      super(logdev)
      self.formatter = formatter
      @config_client = BootstrappingConfigClient.new
      @silences = Concurrent::Map.new(initial_capacity: 2)
      @prefix = "#{prefix}#{prefix && '.'}"

      @log_path_aggregator = log_path_aggregator
    end

    def add(severity, message = nil, progname = nil, loc, &block)
      path_loc = get_loc_path(loc)
      path = @prefix + path_loc

      @log_path_aggregator&.push(path_loc, severity)

      log(message, path, progname, severity, &block)
    end

    def log_internal(message, path = nil, progname, severity, &block)
      path = if path
               "#{INTERNAL_PREFIX}.#{path}"
             else
               INTERNAL_PREFIX
             end

      log(message, path, progname, severity, &block)
    end

    def log(message, path, progname, severity)
      severity ||= ::Logger::UNKNOWN

      return true if @logdev.nil? || severity < level_of(path) || @silences[local_log_id]

      if progname.nil?
        progname = @progname
      end
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end

      @logdev.write(
        format_message(format_severity(severity), Time.now, progname, message, path)
      )
      true
    end

    def debug(progname = nil, &block)
      add(DEBUG, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def info(progname = nil, &block)
      add(INFO, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def warn(progname = nil, &block)
      add(WARN, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def error(progname = nil, &block)
      add(ERROR, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def fatal(progname = nil, &block)
      add(FATAL, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def debug?
      true
    end

    def info?
      true
    end

    def warn?
      true
    end

    def error?
      true
    end

    def fatal?
      true
    end

    def level
      DEBUG
    end

    def set_config_client(config_client)
      @config_client = config_client
    end

    def local_log_id
      Thread.current.__id__
    end

    def silence
      @silences[local_log_id] = true
      yield self
    ensure
      @silences[local_log_id] = false
    end

    private

    NO_DEFAULT = nil

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
      LOG_LEVEL_LOOKUPS[closest_log_level_match_int]
    end

    def get_loc_path(loc)
      loc_path = loc.absolute_path || loc.to_s
      get_path(loc_path, loc.base_label)
    end

    # sanitize & clean the path of the caller so the key
    # looks like log_level.app.models.user
    def get_path(absolute_path, base_label)
      path = (absolute_path || UNKNOWN_PATH).dup
      path.slice! Dir.pwd
      path.gsub!(%r{(.*)?(?=/lib)}im, '') # replace everything before first lib

      path = path.gsub('/', SEP).gsub(/.rb.*/, '') + SEP + base_label
      path.slice! '.lib'
      path.slice! SEP
      path
    end

    def format_message(severity, datetime, progname, msg, path)
      formatter = (@formatter || @default_formatter)

      if formatter.arity == 5
        formatter.call(severity, datetime, progname, msg, path)
      else
        formatter.call(severity, datetime, join_path_and_progname(path, progname), msg)
      end
    end

    def join_path_and_progname(path, progname)
      (progname.nil? || progname.empty?) ? path : "#{progname}: #{path}"
    end
  end

  # StubConfigClient to be used while config client initializes
  # since it may log
  class BootstrappingConfigClient
    def get(_key, default = nil, _properties = {})
      ENV['PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL'] ? ENV['PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL'].upcase.to_sym : default
    end
  end
end
