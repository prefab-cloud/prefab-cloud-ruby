# frozen_string_literal: true

module Prefab
  class NoopCache
    def fetch(_name, _opts)
      yield
    end

    def write(name, value, opts = nil); end

    def read(name); end

    def delete(name); end
  end
end
