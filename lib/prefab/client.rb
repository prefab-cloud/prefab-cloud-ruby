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

        @interceptor = Prefab::AuthInterceptor.new(@api_key)
        @prefab_api_url = @options.prefab_api_url
        @prefab_grpc_url = @options.prefab_grpc_url
        log_internal ::Logger::INFO,
                     "Prefab Connecting to: #{@prefab_api_url} and #{@prefab_grpc_url} Secure: #{http_secure?}"
        at_exit do
          channel.destroy
        end
      end
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

    def channel
      credentials = http_secure? ? creds : :this_channel_is_insecure
      @_channel ||= GRPC::Core::Channel.new(@prefab_grpc_url, nil, credentials)
    end

    def config_client(timeout: 5.0)
      @config_client ||= Prefab::ConfigClient.new(self, timeout)
    end

    def ratelimit_client(timeout: 5.0)
      @ratelimit_client ||= Prefab::RateLimitClient.new(self, timeout)
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

    def log_internal(level, msg, path = nil)
      log.log_internal msg, path, nil, level
    end

    def request(service, method, req_options: {}, params: {})
      # Future-proofing since we previously bumped into a conflict with a service with a `send` method
      raise ArgumentError, 'Cannot call public_send on an grpc service in Ruby' if method.to_s == 'public_send'

      opts = { timeout: 10 }.merge(req_options)

      attempts = 0
      start_time = Time.now

      begin
        attempts += 1

        stub_for(service, opts[:timeout]).public_send(method, *params)
      rescue StandardError => e
        log_internal ::Logger::WARN, e

        raise e if Time.now - start_time > opts[:timeout]

        sleep_seconds = [BASE_SLEEP_SEC * (2**(attempts - 1)), MAX_SLEEP_SEC].min
        sleep_seconds *= (0.5 * (1 + rand))
        sleep_seconds = [BASE_SLEEP_SEC, sleep_seconds].max
        log_internal ::Logger::INFO, "Sleep #{sleep_seconds} and Reset #{service} #{method}"
        sleep sleep_seconds
        reset!
        retry
      end
    end

    def reset!
      @stubs.clear
      @_channel = nil
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

    private

    def is_ff?(key)
      raw = config_client.send(:raw, key)

      raw && raw.allowable_values.any?
    end

    def http_secure?
      ENV['PREFAB_CLOUD_HTTP'] != 'true'
    end

    def stub_for(service, timeout)
      @stubs["#{service}_#{timeout}"] ||= service::Stub.new(nil,
                                                            nil,
                                                            timeout: timeout,
                                                            channel_override: channel,
                                                            interceptors: [@interceptor])
    end

    def creds
      GRPC::Core::ChannelCredentials.new(ssl_certs)
    end

    def ssl_certs
      ssl_certs = ''
      Dir["#{OpenSSL::X509::DEFAULT_CERT_DIR}/*.pem"].each do |cert|
        ssl_certs += File.open(cert).read
      end
      if OpenSSL::X509::DEFAULT_CERT_FILE && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        ssl_certs += File.open(OpenSSL::X509::DEFAULT_CERT_FILE).read
      end
      ssl_certs
    rescue StandardError => e
      log.warn("Issue loading SSL certs #{e.message}")
      ssl_certs
    end
  end
end
