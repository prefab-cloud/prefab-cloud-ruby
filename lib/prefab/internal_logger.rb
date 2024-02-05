module Prefab
  class InternalLogger < SemanticLogger::Logger

    def initialize(klass)
      super(klass, :warn)
      instances << self
    end

    def log(log, message = nil, progname = nil, &block)
      return if recurse_check[local_log_id]
      recurse_check[local_log_id] = true
      begin
        super(log, message, progname, &block)
      ensure
        recurse_check[local_log_id] = false
      end
    end

    def local_log_id
      Thread.current.__id__
    end

    # Our client outputs debug logging,
    # but if you aren't using Prefab logging this could be too chatty.
    # If you aren't using prefab log filter, only log warn level and above
    def self.using_prefab_log_filter!
      @@instances.each do |l|
        l.level = :trace
      end
    end

    private

    def instances
      @@instances ||= []
    end

    def recurse_check
      @recurse_check ||=Concurrent::Map.new(initial_capacity: 2)
    end
  end
end
