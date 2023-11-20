# frozen_string_literal: true

module Prefab
  class LoggerClient < ::Logger
    SEP = '.'
    BASE_KEY = 'log-level'
    UNKNOWN_PATH = 'unknown.'
    LOG_TAGS = 'log.tags'
    REQ_TAGS = 'req.tags'

    LOG_LEVEL_LOOKUPS = {
      PrefabProto::LogLevel::NOT_SET_LOG_LEVEL => ::Logger::DEBUG,
      PrefabProto::LogLevel::TRACE => ::Logger::DEBUG,
      PrefabProto::LogLevel::DEBUG => ::Logger::DEBUG,
      PrefabProto::LogLevel::INFO => ::Logger::INFO,
      PrefabProto::LogLevel::WARN => ::Logger::WARN,
      PrefabProto::LogLevel::ERROR => ::Logger::ERROR,
      PrefabProto::LogLevel::FATAL => ::Logger::FATAL
    }.freeze

    def self.instance
      @@shared_instance ||= LoggerClient.new($stdout)
    end

    def initialize(logdev, log_path_aggregator: nil, formatter: Options::DEFAULT_LOG_FORMATTER, prefix: nil)
      super(logdev)
      self.formatter = formatter
      @config_client = BootstrappingConfigClient.new
      @silences = Concurrent::Map.new(initial_capacity: 2)
      @recurse_check = Concurrent::Map.new(initial_capacity: 2)
      @prefix = "#{prefix}#{prefix && '.'}"

      @context_keys_map = Concurrent::Map.new(initial_capacity: 4)

      @log_path_aggregator = log_path_aggregator
      @@shared_instance = self
    end

    def add_context_keys(*keys)
      context_keys.merge(keys)
    end

    def with_context_keys(*keys)
      context_keys.merge(keys)
      yield
    ensure
      context_keys.subtract(keys)
    end

    def internal_logger(path = nil)
      InternalLogger.new(path, self)
    end

    def context_keys
      @context_keys_map.fetch_or_store(local_log_id, Concurrent::Set.new)
    end

    # InternalLoggers Will Call This
    def add_internal(severity, message, progname, loc, log_context = {}, &block)
      path_loc = get_loc_path(loc)
      path = @prefix + path_loc

      log(message, path, progname, severity, log_context, &block)
    end

    def log_internal(severity, message, path, log_context = {}, &block)
      return if @recurse_check[local_log_id]
      @recurse_check[local_log_id] = true
      begin
        log(message, path, nil, severity, log_context, &block)
      ensure
        @recurse_check[local_log_id] = false
      end
    end

    def log(message, path, progname, severity, log_context = {})
      severity ||= ::Logger::UNKNOWN
      @log_path_aggregator&.push(path, severity)

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
        format_message(format_severity(severity), Time.now, progname, message, path, stringify_keys(log_context.merge(fetch_context_for_context_keys)))
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

    def tagged(*tags)
      to_add = tags.flatten.compact
      if block_given?
        new_log_tags = Prefab::Context.current.get(LOG_TAGS) || []
        new_log_tags += to_add unless to_add.empty?
        Prefab::Context.with_merged_context({ "log" => { "tags" => new_log_tags } }) do
          with_context_keys LOG_TAGS do
            yield self
          end
        end
      else
        new_log_tags = Prefab::Context.current.get(REQ_TAGS) || []
        new_log_tags += to_add unless to_add.empty?
        add_context_keys REQ_TAGS
        Prefab::Context.current.set("req", {"tags": new_log_tags})
        self
      end
    end

    def flush
      Prefab::Context.current.set("req", {"tags": nil})
      super if defined?(super)
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

    def stringify_keys(hash)
      Hash[hash.map { |k, v| [k.to_s, v] }]
    end

    def fetch_context_for_context_keys
      context = Prefab::Context.current.to_h
      Hash[context_keys.map do |key|
        [key, context.dig(*key.split("."))]
      end]
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

    def format_message(severity, datetime, progname, msg, path = nil, log_context = {})
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
