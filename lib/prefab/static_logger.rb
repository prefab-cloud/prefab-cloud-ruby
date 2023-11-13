# frozen_string_literal: true

module Prefab
  class StaticLogger < ::Logger
    def initialize(path)
      @path = path
    end

    def debug(msg = nil, &block) msg
      Prefab::LoggerClient.instance.log_internal ::Logger::DEBUG, msg, @path, &block
    end

    def info(msg = nil, &block) msg
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, msg, @path, &block
    end

    def warn(msg = nil, &block) msg
      Prefab::LoggerClient.instance.log_internal ::Logger::WARN, msg, @path, &block
    end

    def error(msg = nil, &block) msg
      Prefab::LoggerClient.instance.log_internal ::Logger::ERROR, msg, @path, &block
    end

    def fatal(msg = nil, &block) msg
      Prefab::LoggerClient.instance.log_internal ::Logger::FATAL, msg, @path, &block
    end
  end
end
