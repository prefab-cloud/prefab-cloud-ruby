# frozen_string_literal: true

module Prefab
  module Errors
    class InitializationTimeoutError < Prefab::Error
      def initialize(timeout_sec, key)
        message = "Prefab couldn't initialize in #{timeout_sec} second timeout. Trying to fetch key `#{key}`."

        super(message)
      end
    end
  end
end
