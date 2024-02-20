module Prefab
  class InternalLogger < SemanticLogger::Logger
    @@use_filter_latch = Concurrent::CountDownLatch.new(1)
    @@recurse_check = Concurrent::Map.new(initial_capacity: 2)

    def initialize(klass)
      super(klass, :trace)
    end

    def log(log, message = nil, progname = nil, &block)
      return if @@recurse_check[local_log_id]
      @@recurse_check[local_log_id] = true
      begin
        super(log, message, progname, &block)
      ensure
        @@recurse_check[local_log_id] = false
      end
    end

    # Our client outputs debug logging,
    # but if you aren't using Prefab logging this could be too chatty.
    # If you aren't using prefab log filter, only log warn level and above
    def meets_log_level?(log)
      if @@use_filter_latch.count <= 0
        super(log)
      else
        (SemanticLogger::Levels.index(:warn) <= (log.level_index || 0))
      end
    end

    def local_log_id
      Thread.current.__id__
    end

    def self.using_prefab_log_filter!
      @@use_filter_latch.count_down
    end
  end
end
