# frozen_string_literal: true

require 'uuid'

module Prefab
  class Client
    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5

    attr_reader :shared_cache, :stats, :namespace, :interceptor, :api_key, :prefab_api_url, :options, :instance_hash

    def initialize(options = Prefab::Options.new)
      @options = options.is_a?(Prefab::Options) ? options : Prefab::Options.new(options)
      @shared_cache = @options.shared_cache
      @stats = @options.stats
      @namespace = @options.namespace
      @stubs = {}
      @instance_hash = UUID.new.generate

      if @options.local_only?
        log_internal ::Logger::INFO, 'Prefab Running in Local Mode'
      else
        @api_key = @options.api_key
        raise Prefab::Errors::InvalidApiKeyError, @api_key if @api_key.nil? || @api_key.empty? || api_key.count('-') < 1

        @prefab_api_url = @options.prefab_api_url
        log_internal ::Logger::INFO, "Prefab Connecting to: #{@prefab_api_url}"
      end

      context.clear
      # start config client
      config_client
    end

    def with_log_context(_lookup_key, properties, &block)
      warn '[DEPRECATION] `$prefab.with_log_context` is deprecated.  Please use `with_context` instead.'
      with_context(properties, &block)
    end

    def with_context(context, register_as: nil, &block)
      Prefab::Context.with_context(context, register_as: register_as, &block)
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

    def log_path_collector
      return nil if @options.collect_max_paths <= 0

      @log_path_collector ||= LogPathCollector.new(client: self, max_paths: @options.collect_max_paths,
                                                   sync_interval: @options.collect_sync_interval)
    end

    def log
      @logger_client ||= @options.logger_class.new(@options.logdev, formatter: @options.log_formatter,
                                                                    prefix: @options.log_prefix,
                                                                    log_path_collector: log_path_collector)
    end

    def set_rails_loggers
      Rails.logger = log
      ActionView::Base.logger = log
      ActionController::Base.logger = log
      ActiveJob::Base.logger = log if defined?(ActiveJob)
      ActiveRecord::Base.logger = log
      ActiveStorage.logger = log if defined?(ActiveStorage)
    end

    def on_update(&block)
      resolver.on_update(&block)
    end

    def log_internal(level, msg, path = nil)
      log.log_internal msg, path, nil, level
    end

    def enabled?(feature_name, lookup_key = NO_DEFAULT_PROVIDED, properties = NO_DEFAULT_PROVIDED)
      _, properties = handle_positional_arguments(lookup_key, properties, :enabled?)

      feature_flag_client.feature_is_on_for?(feature_name, properties)
    end

    def get(key, default_or_lookup_key = NO_DEFAULT_PROVIDED, properties = NO_DEFAULT_PROVIDED, ff_default = nil)
      if is_ff?(key)
        _, properties = handle_positional_arguments(default_or_lookup_key, properties, :get)

        feature_flag_client.get(key, properties, default: ff_default)
      else
        config_client.get(key, default_or_lookup_key, properties)
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
      Prefab::Client.new(@options)
    end

    private

    def is_ff?(key)
      raw = config_client.send(:raw, key)

      raw && raw.allowable_values.any?
    end

    # The goal here is to ease transition from the old API to the new one. The
    # old API had a lookup_key parameter that is deprecated. This method
    # handles the transition by checking if the first parameter is a string and
    # if so, it is assumed to be the lookup_key and a deprecation warning is
    # issued and we know the second argument is the properties. If the first
    # parameter is a hash, you're on the new API and no further action is
    # required.
    def handle_positional_arguments(lookup_key, properties, method)
      # handle JIT context
      if lookup_key.is_a?(Hash) && properties == NO_DEFAULT_PROVIDED
        properties = lookup_key
        lookup_key = nil
      end

      if lookup_key.is_a?(String)
        warn "[DEPRECATION] `$prefab.#{method}`'s lookup_key argument is deprecated. Please remove it or use context instead."
      end

      [lookup_key, properties]
    end
  end
end
