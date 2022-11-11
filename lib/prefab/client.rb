# frozen_string_literal: true
module Prefab
  class Client
    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5
    NO_DEFAULT_PROVIDED = :no_default_provided

    attr_reader :shared_cache, :stats, :namespace, :interceptor, :api_key, :prefab_api_url, :options

    def initialize(options = Prefab::Options.new)
      @options = options
      @shared_cache = @options.shared_cache
      @stats = @options.stats
      @namespace = @options.namespace
      @stubs = {}

      if @options.local_only?
        log_internal Logger::INFO, "Prefab Running in Local Mode"
      else
        @api_key = @options.api_key
        raise Prefab::Errors::InvalidApiKeyError.new(@api_key) if @api_key.nil? || @api_key.empty? || api_key.count("-") < 1
        @interceptor = Prefab::AuthInterceptor.new(@api_key)
        @prefab_api_url = @options.prefab_api_url
        @prefab_grpc_url = @options.prefab_grpc_url
        log_internal Logger::INFO, "Prefab Connecting to: #{@prefab_api_url} and #{@prefab_grpc_url} Secure: #{http_secure?}"
        at_exit do
          channel.destroy
        end
      end
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

    def log
      @logger_client ||= Prefab::LoggerClient.new(@options.logdev, formatter: @options.log_formatter,
                                                                   prefix: @options.log_prefix)
    end

    def log_internal(level, msg, path = nil)
      log.log_internal msg, path || @options.log_prefix, nil, level
    end

    def request(service, method, req_options: {}, params: {})
      opts = { timeout: 10 }.merge(req_options)

      attempts = 0
      start_time = Time.now

      begin
        attempts += 1
        return stub_for(service, opts[:timeout]).send(method, *params)
      rescue => exception

        log_internal Logger::WARN, exception

        if Time.now - start_time > opts[:timeout]
          raise exception
        end
        sleep_seconds = [BASE_SLEEP_SEC * (2 ** (attempts - 1)), MAX_SLEEP_SEC].min
        sleep_seconds = sleep_seconds * (0.5 * (1 + rand()))
        sleep_seconds = [BASE_SLEEP_SEC, sleep_seconds].max
        log_internal Logger::INFO, "Sleep #{sleep_seconds} and Reset #{service} #{method}"
        sleep sleep_seconds
        reset!
        retry
      end
    end

    def reset!
      @stubs.clear
      @_channel = nil
    end

    def enabled?(feature_name, lookup_key=nil, attributes={})
      feature_flag_client.feature_is_on_for?(feature_name, lookup_key, attributes: attributes)
    end

    def get(key, default_or_lookup_key=NO_DEFAULT_PROVIDED, attributes={}, ff_default=NO_DEFAULT_PROVIDED)
      result = config_client.get(key, default_or_lookup_key)

      if result.is_a?(Prefab::FeatureFlag)
        feature_flag_client.get(key, default_or_lookup_key, attributes, default: ff_default)
      else
        result
      end
    end

    private

    def http_secure?
      ENV["PREFAB_CLOUD_HTTP"] != "true"
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
      ssl_certs = ""
      Dir["#{OpenSSL::X509::DEFAULT_CERT_DIR}/*.pem"].each do |cert|
        ssl_certs += File.open(cert).read
      end
      if OpenSSL::X509::DEFAULT_CERT_FILE && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        ssl_certs += File.open(OpenSSL::X509::DEFAULT_CERT_FILE).read
      end
      ssl_certs
    rescue => e
      log.warn("Issue loading SSL certs #{e.message}")
      ssl_certs
    end

  end
end

