# frozen_string_literal: true

module Prefab
  class InternalLogger < ::Logger
    def initialize(path, logger)
      @path = path
      @logger = logger
    end

    def debug msg, path = nil
      @logger.log_internal ::Logger::DEBUG, msg, path
    end

    def info msg, path = nil
      @logger.log_internal ::Logger::INFO, msg, path
    end

    def warn msg, path = nil
      @logger.log_internal ::Logger::WARN, msg, path
    end

    def error msg, path = nil
      @logger.log_internal ::Logger::ERROR, msg, path
    end

    def fatal msg, path = nil
      @logger.log_internal ::Logger::FATAL, msg, path
    end
  end
end
