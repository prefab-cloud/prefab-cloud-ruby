module Prefab
  module PeriodicSync
    def sync
      return if @data.size.zero?

      log_internal "Syncing #{@data.size} items"

      start_at_was = @start_at
      @start_at = now

      flush(prepare_data, start_at_was)
    end

    def prepare_data
      to_ship = @data.dup
      @data.clear
      to_ship
    end

    def start_periodic_sync(sync_interval)
      @start_at = now

      @sync_interval = if sync_interval.is_a?(Numeric)
                         proc { sync_interval }
                       else
                         sync_interval || ExponentialBackoff.new(initial_delay: 8, max_delay: 60 * 10)
                       end

      @pool = Concurrent::ThreadPoolExecutor.new(
        fallback_policy: :discard,
        max_queue: 5,
        max_threads: 4,
        min_threads: 1,
        name: @name
      )

      Thread.new do
        log_internal "Initialized #{@name} instance_hash=#{@client.instance_hash} max_paths=#{@max_paths}"

        loop do
          sleep @sync_interval.call
          sync
        end
      end
    end

    def log_internal(message)
      @client.log.log_internal message, @name, nil, ::Logger::DEBUG
    end

    def now
      (Time.now.utc.to_f * 1000).to_i
    end
  end
end
