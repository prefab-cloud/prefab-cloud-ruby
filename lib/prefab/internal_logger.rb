# frozen_string_literal: true

module Prefab
  class InternalLogger < Logger
    def initialize(path, logger)
      @path = path
      @logger = logger
    end

    def debug(progname = nil)
      @logger.log_internal yield, @path, progname, DEBUG
    end

    def info(progname = nil)
      @logger.log_internal yield, @path, progname, INFO
    end

    def warn(progname = nil)
      @logger.log_internal yield, @path, progname, WARN
    end

    def error(progname = nil)
      @logger.log_internal yield, @path, progname, ERROR
    end

    def fatal(progname = nil)
      @logger.log_internal yield, @path, progname, FATAL
    end
  end
end
