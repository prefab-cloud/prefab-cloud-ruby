# frozen_string_literal: true

require 'uuid'

module Prefab
  class Client
    LOG = Prefab::InternalLogger.new(self)
    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5

    attr_reader :namespace, :interceptor, :api_key, :prefab_api_url, :options, :instance_hash

    def initialize(options = Prefab::Options.new)
      @options = options.is_a?(Prefab::Options) ? options : Prefab::Options.new(options)
      @namespace = @options.namespace
      @stubs = {}
      @instance_hash = UUID.new.generate

      if @options.local_only?
        LOG.debug 'Prefab Running in Local Mode'
      elsif @options.datafile?
        LOG.debug 'Prefab Running in DataFile Mode'
      else
        @api_key = @options.api_key
        raise Prefab::Errors::InvalidApiKeyError, @api_key if @api_key.nil? || @api_key.empty? || api_key.count('-') < 1

        @prefab_api_url = @options.prefab_api_url
        LOG.debug "Prefab Connecting to: #{@prefab_api_url}"
      end

      context.clear
      # start config client
      config_client
    end

    def with_context(properties, &block)
      Prefab::Context.with_context(properties, &block)
    end

    def context
      Prefab::Context.current
    end

    def config_client(timeout: 5.0)
      @config_client ||= Prefab::ConfigClient.new(self, timeout)
    end

    def feature_flag_client
      @feature_flag_client ||= Prefab::FeatureFlagClient.new(self)
    end

    def log_path_aggregator
      return nil if @options.collect_max_paths <= 0

      @log_path_aggregator ||= LogPathAggregator.new(client: self, max_paths: @options.collect_max_paths,
                                                     sync_interval: @options.collect_sync_interval)
    end

    def log
      @log ||= Prefab::LoggerClient.new(client: self, log_path_aggregator: log_path_aggregator)
    end

    def context_shape_aggregator
      return nil if @options.collect_max_shapes <= 0

      @context_shape_aggregator ||= ContextShapeAggregator.new(client: self, max_shapes: @options.collect_max_shapes,
                                                               sync_interval: @options.collect_sync_interval)
    end

    def example_contexts_aggregator
      return nil if @options.collect_max_example_contexts <= 0

      @example_contexts_aggregator ||= ExampleContextsAggregator.new(
        client: self,
        max_contexts: @options.collect_max_example_contexts,
        sync_interval: @options.collect_sync_interval
      )
    end

    def evaluation_summary_aggregator
      return nil if @options.collect_max_evaluation_summaries <= 0

      @evaluation_summary_aggregator ||= EvaluationSummaryAggregator.new(
        client: self,
        max_keys: @options.collect_max_evaluation_summaries,
        sync_interval: @options.collect_sync_interval
      )
    end

    def set_rails_loggers
      Rails.logger = log
      ActionView::Base.logger = log
      ActionController::Base.logger = log
      ActiveJob::Base.logger = log if defined?(ActiveJob)
      ActiveRecord::Base.logger = log
      ActiveStorage.logger = log if defined?(ActiveStorage)

      LogSubscribers::ActionControllerSubscriber.attach_to :action_controller unless @options.disable_action_controller_logging
    end

    def on_update(&block)
      resolver.on_update(&block)
    end

    def enabled?(feature_name, jit_context = NO_DEFAULT_PROVIDED)
      feature_flag_client.feature_is_on_for?(feature_name, jit_context)
    end

    def get(key, default = NO_DEFAULT_PROVIDED, jit_context = NO_DEFAULT_PROVIDED)
      if is_ff?(key)
        feature_flag_client.get(key, jit_context, default: default)
      else
        config_client.get(key, default, jit_context)
      end
    end

    def post(path, body)
      Prefab::HttpConnection.new(@options.prefab_api_url, @api_key).post(path, body)
    end

    def inspect
      "#<Prefab::Client:#{object_id} namespace=#{namespace}>"
    end

    def resolver
      config_client.resolver
    end

    # When starting a forked process, use this to re-use the options
    # on_worker_boot do
    #   $prefab = $prefab.fork
    #   $prefab.set_rails_loggers
    # end
    def fork
      log_options = self.log.context_keys.to_a # get keys pre-fork
      Prefab::Client.new(@options.for_fork).tap do |client|
        client.log.add_context_keys(*log_options)
      end
    end

    private

    def is_ff?(key)
      raw = config_client.send(:raw, key)

      raw && raw.allowable_values.any?
    end
  end
end
