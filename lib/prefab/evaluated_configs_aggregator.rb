# frozen_string_literal: true

require_relative 'periodic_sync'

module Prefab
  class EvaluatedConfigsAggregator
    include Prefab::PeriodicSync

    attr_reader :data

    def initialize(client:, max_configs:, sync_interval:)
      @max_configs = max_configs
      @client = client
      @name = 'evaluated_configs_aggregator'

      @data = Concurrent::Array.new

      start_periodic_sync(sync_interval)
    end

    def push(evaluation)
      return if @data.size >= @max_configs

      @data.push(evaluation)
    end

    def prepare_data
      to_ship = @data.dup
      @data.clear

      to_ship.map { |e| coerce_to_proto(e) }
    end

    def coerce_to_proto(evaluation)
      config, result, context = evaluation

      PrefabProto::EvaluatedConfig.new(
        key: config.key,
        config_version: config.id,
        result: result,
        context: context.to_proto(@client.namespace),
        timestamp: Prefab::TimeHelpers.now_in_ms
      )
    end

    private

    def flush(to_ship, _)
      @pool.post do
        log_internal "Uploading evaluated keys for #{to_ship.size}"

        configs = PrefabProto::EvaluatedConfigs.new(configs: to_ship)

        result = @client.post('/api/v1/evaluated-configs', configs)

        log_internal "Uploaded #{to_ship.size} keys: #{result.status}"
      end
    end
  end
end
