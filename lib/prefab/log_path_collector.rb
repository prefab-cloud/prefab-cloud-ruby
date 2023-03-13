# frozen_string_literal: true

module Prefab
  class LogPathCollector
    INCREMENT = ->(count) { (count || 0) + 1 }

    SEVERITY_KEY = {
      ::Logger::DEBUG => 'debugs',
      ::Logger::INFO => 'infos',
      ::Logger::WARN => 'warns',
      ::Logger::ERROR => 'errors',
      ::Logger::FATAL => 'fatals'
    }.freeze

    def initialize(client:, max_paths:, sync_interval:)
      @max_paths = max_paths
      @sync_interval = sync_interval
      @client = client
      @start_at = now

      @pool = Concurrent::ThreadPoolExecutor.new(
        fallback_policy: :discard,
        max_queue: 5,
        max_threads: 4,
        min_threads: 1,
        name: 'prefab-log-paths'
      )

      @paths = Concurrent::Map.new

      start_periodic_sync
    end

    def push(path, severity)
      return unless @paths.size < @max_paths

      @paths.compute([path, severity], &INCREMENT)
    end

    private

    def sync
      return if @paths.size.zero?

      log_internal "Syncing #{@paths.size} paths"

      flush
    end

    def flush
      to_ship = @paths.dup
      @paths.clear

      start_at_was = @start_at
      @start_at = now

      @pool.post do
        log_internal "Uploading stats for #{to_ship.size} paths"

        aggregate = Hash.new { |h, k| h[k] = Prefab::Logger.new }

        to_ship.each do |(path, severity), count|
          aggregate[path][SEVERITY_KEY[severity]] = count
          aggregate[path]['logger_name'] = path
        end

        loggers = Prefab::Loggers.new(
          loggers: aggregate.values,
          start_at: start_at_was,
          end_at: now,
          instance_hash: @client.instance_hash,
          namespace: @client.namespace
        )

        @client.request Prefab::LoggerReportingService, :send, req_options: {}, params: loggers
      end
    end

    def start_periodic_sync
      Thread.new do
        log_internal "Initialized log path collector instance_hash=#{@client.instance_hash} max_paths=#{@max_paths} sync_interval=#{@sync_interval}"

        loop do
          sleep @sync_interval
          sync
        end
      end
    end

    def log_internal(message)
      @client.log.log_internal message, 'log_path_collector', nil, ::Logger::INFO
    end

    def now
      (Time.now.utc.to_f * 1000).to_i
    end
  end
end
