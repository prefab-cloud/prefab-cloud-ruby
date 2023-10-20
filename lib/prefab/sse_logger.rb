# frozen_string_literal: true

module Prefab
  class SseLogger < ::Logger
    def initialize()
      @path = "sse"
    end

    def debug(progname = nil, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::DEBUG, progname, @path, &block
    end

    def info(progname = nil, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, progname, @path, &block
    end

    # The SSE::Client warns on a perfectly normal stream disconnect, recast to info
    def warn(progname = nil, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, progname, @path, &block
    end

    def error(progname = nil, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::ERROR, progname, @path, &block
    end

    def fatal(progname = nil, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::FATAL, progname, @path, &block
    end
  end
end
