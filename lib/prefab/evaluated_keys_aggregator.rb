# frozen_string_literal: true

require_relative 'periodic_sync'

module Prefab
  class EvaluatedKeysAggregator
    include Prefab::PeriodicSync

    attr_reader :data

    def initialize(client:, max_keys:, sync_interval:)
      @max_keys = max_keys
      @client = client
      @name = 'evaluated_keys_aggregator'

      @data = Concurrent::Set.new

      start_periodic_sync(sync_interval)
    end

    def push(key)
      return if @data.size >= @max_keys

      @data.add(key)
    end

    private

    def flush(to_ship, _)
      pool.post do
        log_internal "Uploading evaluated keys for #{to_ship.size}"

        keys = PrefabProto::EvaluatedKeys.new(keys: to_ship.to_a, namespace: @client.namespace)

        result = @client.post('/api/v1/evaluated-keys', keys)

        log_internal "Uploaded #{to_ship.size} keys: #{result.status}"
      end
    end
  end
end
