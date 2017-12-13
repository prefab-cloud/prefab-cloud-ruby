require "concurrent/atomics"

module EzConfig
  class Store
    def initialize
      @store = Concurrent::Map
      @lock = Concurrent::ReadWriteLock.new
    end

    def get(key)
      @lock.with_read_lock do
        @store[key]
      end
    end

    def all
      @lock.with_read_lock do
        @store.all
      end
    end

    def init(fs)
      @lock.with_write_lock do
        @store.replace(fs)
        @initialized.make_true
      end
    end
  end
end
