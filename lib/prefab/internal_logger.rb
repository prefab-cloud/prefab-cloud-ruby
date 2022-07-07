module Prefab
  class InternalLogger < Logger
    def initialize(path, logger)
      @path = path
      @logger = logger
    end

    def debug(progname = nil, &block)
      @logger.log_internal yield, @path, progname, DEBUG
    end

    def info(progname = nil, &block)
      @logger.log_internal yield, @path, progname, INFO
    end

    def warn(progname = nil, &block)
      @logger.log_internal yield, @path, progname, WARN
    end

    def error(progname = nil, &block)
      @logger.log_internal yield, @path, progname, ERROR
    end

    def fatal(progname = nil, &block)
      @logger.log_internal yield, @path, progname, FATAL
    end
  end
end
