# frozen_string_literal: true

module Prefab
  class SseLogger < ::Logger
    def initialize(logger)
      @path = "sse"
      @logger = logger
    end

    def debug(progname = nil)
      @logger.log_internal ::Logger::DEBUG, progname, @path
    end

    def info(progname = nil)
      @logger.log_internal ::Logger::INFO, progname, @path
    end

    # The SSE::Client warns on a perfectly normal stream disconnect, recast to info
    def warn(progname = nil)
      @logger.log_internal ::Logger::INFO, progname, @path
    end

    def error(progname = nil)
      @logger.log_internal ::Logger::ERROR, progname, @path
    end

    def fatal(progname = nil)
      @logger.log_internal ::Logger::FATAL, progname, @path
    end
  end
end
