# frozen_string_literal: true
module Prefab
  class LoggerClient < Logger

    SEP = "."
    BASE = "log_level"
    UNKNOWN = "unknown"

    def initialize(logdev, formatter: nil)
      super(logdev)
      self.formatter= formatter
      @config_client = BootstrappingConfigClient.new
      @silences = Concurrent::Map.new(:initial_capacity => 2)
    end

    def add(severity, message = nil, progname = nil)
      loc = caller_locations(1, 1)[0]
      add_internal(severity, message, progname, loc)
    end

    def add_internal(severity, message = nil, progname = nil, loc, &block)
      path = get_path(loc.absolute_path, loc.base_label)
      log_internal(message, path, progname, severity, &block)
    end

    def log_internal(message, path, progname, severity, &block)
      level = level_of(path)
      progname = "#{path}: #{progname}"
      severity ||= UNKNOWN
      if @logdev.nil? || severity < level || @silences[local_log_id]
        return true
      end
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
        format_message(format_severity(severity), Time.now, progname, message))
      true
    end

    def debug(progname = nil, &block)
      add_internal(DEBUG, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def info(progname = nil, &block)
      add_internal(INFO, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def warn(progname = nil, &block)
      add_internal(WARN, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def error(progname = nil, &block)
      add_internal(ERROR, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def fatal(progname = nil, &block)
      add_internal(FATAL, nil, progname, caller_locations(1, 1)[0], &block)
    end

    def debug?
      true;
    end

    def info?
      true;
    end

    def warn?
      true;
    end

    def error?
      true;
    end

    def fatal?
      true;
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

    # Find the closest match to 'log_level.path' in config
    def level_of(path)
      closest_log_level_match = @config_client.get(BASE, :warn)
      path.split(SEP).inject([BASE]) do |memo, n|
        memo << n
        val = @config_client.get(memo.join(SEP), nil)
        unless val.nil?
          closest_log_level_match = val
        end
        memo
      end
      val(closest_log_level_match)
    end

    # sanitize & clean the path of the caller so the key
    # looks like log_level.app.models.user
    def get_path(absolute_path, base_label)
      path = (absolute_path || UNKNOWN).dup
      path.slice! Dir.pwd

      path.gsub!(/.*?(?=\/lib\/)/im, "")

      path = "#{path.gsub("/", SEP).gsub(".rb", "")}#{SEP}#{base_label}"
      path.slice! ".lib"
      path.slice! SEP
      path
    end

    def val level
      return Object.const_get("Logger::#{level.upcase}")
    end
  end

  # StubConfigClient to be used while config client initializes
  # since it may log
  class BootstrappingConfigClient
    def get(key, default=nil)
      ENV["PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL"] || default
    end
  end
end

