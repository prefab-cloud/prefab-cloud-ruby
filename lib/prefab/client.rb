module Prefab
  class Client

    attr_reader :account_id, :shared_cache, :stats, :namespace, :logger

    def initialize(api_key:,
                   ssl_certs: "/usr/local/etc/openssl/cert.pem",
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
      @creds = GRPC::Core::ChannelCredentials.new(File.open(ssl_certs).read)

      @channel = GRPC::Core::Channel.new('api.prefab.cloud:8443', nil, @creds)
      if local
        @channel = GRPC::Core::Channel.new('localhost:8443', nil, :this_channel_is_insecure)
      end
    end

    def config_client
      @config_client ||= Prefab::ConfigClient.new(Prefab::ConfigService::Stub.new(nil,
                                                                                  @creds,
                                                                                  channel_override: @channel,
                                                                                  interceptors: [@interceptor]),
                                                  self)
    end

    def ratelimit_client
      @ratelimit_client ||= Prefab::RateLimitClient.new(Prefab::RateLimitService::Stub.new(nil,
                                                                                           @creds,
                                                                                           channel_override: @channel,
                                                                                           interceptors: [@interceptor]),
                                                        self)
    end
  end
end

