# frozen_string_literal: true

module Prefab
  class StaticLogger < ::Logger
    def initialize(path)
      @path = path
    end

    def debug(msg = nil, **log_context, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::DEBUG, msg, @path, log_context, &block
    end

    def info(msg = nil, **log_context, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, msg, @path, log_context, &block
    end

    def warn(msg = nil, **log_context, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::WARN, msg, @path, log_context, &block
    end

    def error(msg = nil, **log_context, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::ERROR, msg, @path, log_context, &block
    end

    def fatal(msg = nil, **log_context, &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::FATAL, msg, @path, log_context, &block
    end
  end
end
