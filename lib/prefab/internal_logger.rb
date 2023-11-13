# frozen_string_literal: true

module Prefab
  class InternalLogger < StaticLogger
    INTERNAL_PREFIX = 'cloud.prefab.client'

    def initialize(path)
      if path.is_a?(Class)
        path_string = path.name.split('::').last.downcase
      else
        path_string = path
      end
      super("#{INTERNAL_PREFIX}.#{path_string}")
    end
  end
end
