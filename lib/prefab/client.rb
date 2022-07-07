module Prefab

  class Client
    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5

    attr_reader :project_id, :shared_cache, :stats, :namespace, :interceptor, :api_key, :prefab_api_url, :options

    def initialize(options = Prefab::Options.new)
      @options = options
      @shared_cache = @options.shared_cache
      @stats = @options.stats
      @namespace = @options.namespace
      @stubs = {}

      if @options.local_only?
        @project_id = 0
        log_internal Logger::INFO, "Prefab Running in Local Mode"
      else
        @api_key = @options.api_key
        raise "No API key. Set PREFAB_API_KEY env var or use PREFAB_DATASOURCES=LOCAL_ONLY" if @api_key.nil? || @api_key.empty?
        raise "PREFAB_API_KEY format invalid. Expecting 123-development-yourapikey-SDK" unless @api_key.count("-") == 3
        @project_id = @api_key.split("-")[0].to_i # unvalidated, but that's ok. APIs only listen to the actual passwd
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
      @logger_client ||= Prefab::LoggerClient.new(@options.logdev, formatter: @options.log_formatter)
    end

    def log_internal(level, msg, path = "prefab")
      log.log_internal msg, path, nil, level
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

    def cache_key(post_fix)
      "prefab:#{project_id}:#{post_fix}"
    end

    def reset!
      @stubs.clear
      @_channel = nil
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
        ssl_certs << File.open(cert).read
      end
      if OpenSSL::X509::DEFAULT_CERT_FILE && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        ssl_certs << File.open(OpenSSL::X509::DEFAULT_CERT_FILE).read
      end
      ssl_certs
    rescue => e
      log.warn("Issue loading SSL certs #{e.message}")
      ssl_certs
    end

  end
end

