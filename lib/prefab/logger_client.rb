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
    }.freeze

    def initialize(logdev, log_path_aggregator: nil, formatter: nil, prefix: nil)
      super(logdev)
      self.formatter = formatter
      @config_client = BootstrappingConfigClient.new
      @silences = Concurrent::Map.new(initial_capacity: 2)
      @prefix = "#{prefix}#{prefix && '.'}"

      @log_path_aggregator = log_path_aggregator
    end

    def add_internal(severity, message, progname, loc, log_context={}, &block)
      path_loc = get_loc_path(loc)
      path = @prefix + path_loc

      @log_path_aggregator&.push(path_loc, severity)

      log(message, path, progname, severity, log_context, &block)
    end

    def log_internal(message, path, progname, severity, log_context={}, &block)
      path = if path
               "#{INTERNAL_PREFIX}.#{path}"
             else
               INTERNAL_PREFIX
             end

      log(message, path, progname, severity, log_context, &block)
    end

    def log(message, path, progname, severity, log_context={})
      severity ||= ::Logger::UNKNOWN

      return true if @logdev.nil? || severity < level_of(path) || @silences[local_log_id]

      progname = @progname if progname.nil?

      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end

      @logdev.write(
        format_message(format_severity(severity), Time.now, progname, message, path, log_context)
      )
      true
    end

    def debug(progname = nil, **log_context, &block)
      add_internal(DEBUG, nil, progname, caller_locations(1, 1)[0], log_context, &block)
    end

    def info(progname = nil, **log_context, &block)
      add_internal(INFO, nil, progname, caller_locations(1, 1)[0], log_context, &block)
    end

    def warn(progname = nil, **log_context, &block)
      add_internal(WARN, nil, progname, caller_locations(1, 1)[0], log_context, &block)
    end

    def error(progname = nil, **log_context, &block)
      add_internal(ERROR, nil, progname, caller_locations(1, 1)[0], log_context, &block)
    end

    def fatal(progname = nil, **log_context, &block)
      add_internal(FATAL, nil, progname, caller_locations(1, 1)[0], log_context, &block)
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

    def config_client=(config_client)
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

    def format_message(severity, datetime, progname, msg, path = nil, log_context={})
      formatter = (@formatter || @default_formatter)

      formatter.call(
        severity: severity,
        datetime: datetime,
        progname: progname,
        path: path,
        message: msg,
        log_context: log_context
      )
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
