module Prefab
  class InternalLogger < SemanticLogger::Logger
    @@recurse_check = Concurrent::Map.new(initial_capacity: 2)

    def initialize(klass, level = nil, filter = nil)
      super(klass, level, filter)
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

    def local_log_id
      Thread.current.__id__
    end
  end
end
