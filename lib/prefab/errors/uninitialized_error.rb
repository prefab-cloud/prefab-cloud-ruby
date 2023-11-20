# frozen_string_literal: true

module Prefab
  module Errors
    class UninitializedError < Prefab::Error
      def initialize(key=nil)
        message = "Use Prefab.initialize before calling Prefab.get #{key}"

        super(message)
      end
    end
  end
end
