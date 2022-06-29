module Prefab
  class Client

    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5
    DEFAULT_LOG_FORMATTER = proc {|severity, datetime, progname, msg|
      "#{severity.ljust(5)} #{datetime}: #{progname} #{msg}\n"
    }

    attr_reader :project_id, :shared_cache, :stats, :namespace, :interceptor, :api_key, :prefab_api_url

    def initialize(api_key: ENV['PREFAB_API_KEY'],
                   logdev: nil,
                   stats: nil, # receives increment("prefab.limitcheck", {:tags=>["policy_group:page_view", "pass:true"]})
                   shared_cache: nil, # Something that quacks like Rails.cache ideally memcached
                   namespace: "",
                   log_formatter: DEFAULT_LOG_FORMATTER
    )
      log_internal Logger::ERROR, "No API key. Set PREFAB_API_KEY env var" if api_key.nil? || api_key.empty?
      log_internal Logger::ERROR, "PREFAB_API_KEY format invalid. Expecting 123-development-yourapikey-SDK" unless api_key.count("-") == 3
      @logdev = (logdev || $stdout)
      @log_formatter = log_formatter
      @stats = (stats || NoopStats.new)
      @shared_cache = (shared_cache || NoopCache.new)
      @api_key = api_key
      @project_id = api_key.split("-")[0].to_i # unvalidated, but that's ok. APIs only listen to the actual passwd
      @namespace = namespace
      @interceptor = Prefab::AuthInterceptor.new(api_key)
      @stubs = {}
      @prefab_api_url = ENV["PREFAB_API_URL"] || 'https://api.prefab.cloud'
      @prefab_grpc_url = ENV["PREFAB_GRPC_URL"] || 'grpc.prefab.cloud:443'
      log_internal Logger::INFO, "Prefab Connecting to: #{@prefab_api_url} and #{@prefab_grpc_url} Secure: #{http_secure?}"
      at_exit do
        channel.destroy
      end
    end

    def channel
      credentials = http_secure? ? creds : :this_channel_is_insecure
      log_internal Logger::DEBUG, "GRPC Channel #{@prefab_grpc_url} #{credentials}"
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
      @logger_client ||= Prefab::LoggerClient.new(@logdev, formatter: @log_formatter)
    end

    def log_internal(level, msg)
      log.log_internal msg, "prefab", nil, level
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
      if OpenSSL::X509::DEFAULT_CERT_FILE && File.exists?(OpenSSL::X509::DEFAULT_CERT_FILE)
        ssl_certs << File.open(OpenSSL::X509::DEFAULT_CERT_FILE).read
      end
      ssl_certs
    rescue => e
      log.warn("Issue loading SSL certs #{e.message}")
      ssl_certs
    end

  end
end

