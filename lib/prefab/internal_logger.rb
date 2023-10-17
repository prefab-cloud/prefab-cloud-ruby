# frozen_string_literal: true

module Prefab
  class InternalLogger < ::Logger
    def initialize(path)
      if path.is_a?(Class)
        @path = path.name.split('::').last.downcase
      else
        @path = path
      end
    end

    def debug msg
      Prefab::LoggerClient.instance.log_internal ::Logger::DEBUG, msg, @path
    end

    def info msg
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, msg, @path
    end

    def warn msg
      Prefab::LoggerClient.instance.log_internal ::Logger::WARN, msg, @path
    end

    def error msg
      Prefab::LoggerClient.instance.log_internal ::Logger::ERROR, msg, @path
    end

    def fatal msg
      Prefab::LoggerClient.instance.log_internal ::Logger::FATAL, msg, @path
    end
  end
end
