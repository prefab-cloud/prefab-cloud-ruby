# frozen_string_literal: true

module Prefab
  module Errors
    class MissingDefaultError < Prefab::Error
      def initialize(key)
        message = "No value found for key '#{key}' and no default was provided.\n\nIf you'd prefer returning `nil` rather than raising when this occurs, modify the `on_no_default` value you provide in your Prefab::Options."

        super(message)
      end
    end
  end
end
