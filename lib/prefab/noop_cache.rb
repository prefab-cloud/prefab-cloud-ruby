module Prefab
  class NoopCache
    def fetch(name, opts, &method)
      yield
    end

    def write(name, value, opts=nil)
    end

    def read(name)
    end

    def delete(name)
    end
  end
end
