# frozen_string_literal: true

require 'uuid'

module Prefab
  class Client
    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5
    NO_DEFAULT_PROVIDED = :no_default_provided

    attr_reader :shared_cache
    attr_reader :stats
    attr_reader :namespace
    attr_reader :interceptor
    attr_reader :api_key
    attr_reader :prefab_api_url
    attr_reader :options
    attr_reader :instance_hash

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
      # start config client
      config_client
    end

    def with_log_context(lookup_key, properties)
      Thread.current[:prefab_log_lookup_key] = lookup_key
      Thread.current[:prefab_log_properties] = properties

      yield
    ensure
      Thread.current[:prefab_log_lookup_key] = nil
      Thread.current[:prefab_log_properties] = {}
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
      @logger_client ||= Prefab::LoggerClient.new(@options.logdev, formatter: @options.log_formatter,
                                                                   prefix: @options.log_prefix,
                                                                   log_path_collector: log_path_collector)
    end

    def set_rails_loggers
      Rails.logger = log
      ActionView::Base.logger = log
      ActionController::Base.logger = log
      ActiveJob::Base.logger = log
      ActiveRecord::Base.logger = log
      ActiveStorage.logger = log if defined?(ActiveStorage)
    end

    def log_internal(level, msg, path = nil)
      log.log_internal msg, path, nil, level
    end

    def enabled?(feature_name, lookup_key = nil, attributes = {})
      feature_flag_client.feature_is_on_for?(feature_name, lookup_key, attributes: attributes)
    end

    def get(key, default_or_lookup_key = NO_DEFAULT_PROVIDED, properties = {}, ff_default = nil)
      if is_ff?(key)
        feature_flag_client.get(key, default_or_lookup_key, properties, default: ff_default)
      else
        config_client.get(key, default_or_lookup_key, properties)
      end
    end

    def post(path, body)
      Prefab::HttpConnection.new(@options.prefab_api_url, @api_key).post(path, body)
    end

    private

    def is_ff?(key)
      raw = config_client.send(:raw, key)

      raw && raw.allowable_values.any?
    end
  end
end
