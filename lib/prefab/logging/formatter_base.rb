# frozen_string_literal: true

module Prefab
  module Logging
    # Shim class to quack like a Rails TaggedLogger
    class FormatterBase < ::Logger
      def initialize(formatter_proc:, logger_client:)
        @formatter_proc = formatter_proc
        @logger_client = logger_client
      end

      def call_proc(data)
        @formatter_proc.call(data)
      end

      def current_tags
        @logger_client.current_tags
      end
    end
  end
end
