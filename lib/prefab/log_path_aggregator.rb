# frozen_string_literal: true

require_relative 'periodic_sync'

module Prefab
  class LogPathAggregator
    include Prefab::PeriodicSync

    INCREMENT = ->(count) { (count || 0) + 1 }

    SEVERITY_KEY = {
      ::Logger::DEBUG => 'debugs',
      ::Logger::INFO => 'infos',
      ::Logger::WARN => 'warns',
      ::Logger::ERROR => 'errors',
      ::Logger::FATAL => 'fatals'
    }.freeze

    attr_reader :data

    def initialize(client:, max_paths:, sync_interval:)
      @max_paths = max_paths
      @client = client
      @name = 'log_path_aggregator'

      @data = Concurrent::Map.new

      @last_data_sent = nil
      @last_request = nil

      start_periodic_sync(sync_interval)
    end

    def push(path, severity)
      return if @data.size >= @max_paths

      @data.compute([path, severity], &INCREMENT)
    end

    private

    def flush(to_ship, start_at_was)
      pool.post do
        log_internal "Uploading stats for #{to_ship.size} paths"

        aggregate = Hash.new { |h, k| h[k] = PrefabProto::Logger.new }

        to_ship.each do |(path, severity), count|
          aggregate[path][SEVERITY_KEY[severity]] = count
          aggregate[path]['logger_name'] = path
        end

        loggers = PrefabProto::Loggers.new(
          loggers: aggregate.values,
          start_at: start_at_was,
          end_at: Prefab::TimeHelpers.now_in_ms,
          instance_hash: @client.instance_hash,
          namespace: @client.namespace
        )

        result = post('/api/v1/known-loggers', loggers)

        log_internal "Uploaded #{to_ship.size} paths: #{result.status}"
      end
    end
  end
end
