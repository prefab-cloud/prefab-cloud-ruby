module Prefab
  class Client
    attr_reader :account_id, :shared_cache, :stats, :namespace, :logger

    def initialize(api_key:,
                   logger: nil,
                   stats: nil, # receives increment("prefab.limitcheck", {:tags=>["policy_group:page_view", "pass:true"]})
                   shared_cache: nil, # Something that quacks like Rails.cache ideally memcached
                   local: false,
                   namespace: ""
    )
      @logger = (logger || Logger.new($stdout)).tap do |log|
        log.progname = "Prefab" if log.respond_to? :progname=
      end
      @stats = (stats || NoopStats.new)
      @shared_cache = (shared_cache || NoopCache.new)
      @account_id = api_key.split("|")[0].to_i
      @namespace = namespace

      @interceptor = AuthInterceptor.new(api_key)

      @creds = GRPC::Core::ChannelCredentials.new(ssl_certs)
      @channel = GRPC::Core::Channel.new('api.prefab.cloud:8443', nil, @creds)
      if local
        @channel = GRPC::Core::Channel.new('localhost:8443', nil, :this_channel_is_insecure)
      end
    end

    def config_client(timeout: 10.0)
      @config_client ||= Prefab::ConfigClient.new(Prefab::ConfigService::Stub.new(nil,
                                                                                  @creds,
                                                                                  channel_override: @channel,
                                                                                  timeout: timeout,
                                                                                  interceptors: [@interceptor]),
                                                  self)
    end

    def ratelimit_client(timeout: 5.0)
      @ratelimit_client ||= Prefab::RateLimitClient.new(Prefab::RateLimitService::Stub.new(nil,
                                                                                           @creds,
                                                                                           channel_override: @channel,
                                                                                           timeout: timeout,
                                                                                           interceptors: [@interceptor]),
                                                        self)
    end

    private

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
      @logger.warn("Issue loading SSL certs #{e.message}")
      ssl_certs
    end

  end
end

