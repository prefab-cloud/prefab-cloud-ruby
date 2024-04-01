# frozen_string_literal: true

require 'iso8601'

module Prefab
  class Duration
    def initialize(definition)
      @seconds = self.class.parse(definition)
    end

    def self.parse(definition)
      ISO8601::Duration.new(definition).to_seconds
    end

    def in_seconds
      @seconds
    end

    def in_minutes
      in_seconds / 60.0
    end

    def in_hours
      in_minutes / 60.0
    end

    def in_days
      in_hours / 24.0
    end

    def in_weeks
      in_days / 7.0
    end

    def to_i
      in_seconds.to_i
    end

    def to_f
      in_seconds.to_f
    end
  end
end
