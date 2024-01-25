# frozen_string_literal: true

module Prefab
  module Errors
    class MissingEnvVarError < Prefab::Error
      def initialize(message)
        super(message)
      end
    end
  end
end
