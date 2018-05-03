module Prefab
  class Client

    MAX_SLEEP_SEC = 10
    BASE_SLEEP_SEC = 0.5

    attr_reader :account_id, :shared_cache, :stats, :namespace, :creds, :interceptor

    def initialize(api_key: ENV['PREFAB_API_KEY'],
                   logdev: nil,
                   stats: nil, # receives increment("prefab.limitcheck", {:tags=>["policy_group:page_view", "pass:true"]})
                   shared_cache: nil, # Something that quacks like Rails.cache ideally memcached
                   local: false,
                   namespace: "",
                   log_formatter: nil
    )
      raise "No API key. Set PREFAB_API_KEY env var" if api_key.nil? || api_key.empty?
      @logdev = (logdev || $stdout)
      @log_formatter = log_formatter
      @local = local
      @stats = (stats || NoopStats.new)
      @shared_cache = (shared_cache || NoopCache.new)
      @account_id = api_key.split("|")[0].to_i
      @namespace = namespace

      @interceptor = AuthInterceptor.new(api_key)
      @creds = GRPC::Core::ChannelCredentials.new(ssl_certs)
      @stubs = {}
    end

    def channel
      @_channel ||= @local ?
                      GRPC::Core::Channel.new('localhost:8443', nil, :this_channel_is_insecure)
                      :
                      GRPC::Core::Channel.new('api.prefab.cloud:8443', nil, @creds)
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
      "prefab:#{account_id}:#{post_fix}"
    end

    private

    def reset!
      @stubs.clear
      @_channel = nil
    end

    def stub_for(service, timeout)
      @stubs["#{service}_#{timeout}"] ||= service::Stub.new(nil,
                                                            nil,
                                                            timeout: timeout,
                                                            channel_override: channel,
                                                            interceptors: [@interceptor])
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

