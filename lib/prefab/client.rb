module Prefab
  class Client

    def initialize(api_key:,
                   ssl_certs: "/usr/local/etc/openssl/cert.pem",
                   local: false
    )
      @resolver = EzConfig::ConfigResolver.new("sem")

      interceptor = AuthInterceptor.new(api_key)
      creds = GRPC::Core::ChannelCredentials.new(File.open(ssl_certs).read)

      @channel = GRPC::Core::Channel.new('api.prefab.cloud:8443', nil, creds)
      if local
        @channel = GRPC::Core::Channel.new('localhost:8443', nil, :this_channel_is_insecure)
      end


      ss = Cloud::Prefab::Domain::ConfigService::Stub.new(nil, creds, channel_override: @channel, interceptors: [interceptor])
      config_req = Cloud::Prefab::Domain::ConfigServicePointer.new(account_id: 1,
                                                                   start_at_id: 0)


      d = Cloud::Prefab::Domain::ConfigDelta.new(account_id: 1,
                                                 key: "db.port",
                                                 value: Cloud::Prefab::Domain::ConfigValue.new(string: "9999"))

      ss.upsert(d)

      Thread.new do
        begin
          resp = ss.get_config(config_req)
          resp.each do |r|
            r.deltas.each do |delta|
              @resolver.set(delta)
            end
            @resolver.update
            puts "updated"
          end
        rescue => e
          puts e
          puts e.backtrace
        end

      end
    end


    def run


      @sem = EzConfig::ConfigResolver.new("sem-tools")
      puts "sem-tools   #{@sem.get "ezauth.api.url"}"

      @ez = EzConfig::ConfigResolver.new("ez-rails")
      puts "ez-rails     #{@ez.get "ezauth.api.url"}"

      @o = EzConfig::ConfigResolver.new("other")
      puts "other        #{@o.get "ezauth.api.url"}"

      sleep(2)
      puts "---------"
      puts "other        #{@o.get "ezauth.api.url"}"
      puts "sem        #{@sem.get "ezauth.api.url"}"
      puts "ez        #{@ez.get "ezauth.api.url"}"
      puts "other        #{@o.get "db.port"}"
      puts "sem        #{@sem.get "db.port"}"
      puts "ez        #{@ez.get "db.port"}"
      puts "real        #{@resolver.get "db.port"}"


      # creds = GRPC::Core::ChannelCredentials.new(load_test_certs)
      #
      # s1 = It::Ratelim::Data::FFLimitService::Stub.new('api.prefab.cloud:8443', creds)
      #
      # req = It::Ratelim::Data::LimitRequest.new
      #
      # respon = s1.ff_limit_check(req)
      # puts "RESPON #{respon}"
      # puts "RESPON #{respon.amount}"
      #
      # stub = It::Ratelim::Data::ConfigService::Stub.new('localhost:8443', :this_channel_is_insecure)
      #
      # config_req = It::Ratelim::Data::ConfigServicePointer.new(account_id: 22,
      #                                                          start_at_id: 0)
      # response = stub.get_config(config_req)
      # response.each do |delta|
      #   @@config[delta.key] = delta.value
      #   @@config.each_key do |k|
      #     puts "#{k} #{@@config[k]}"
      #   end
      # end


    end


    # stub = Helloworld::Greeter::Stub.new('localhost:50051', :this_channel_is_insecure)
    # user = ARGV.size > 0 ?  ARGV[0] : 'world'
    # message = stub.say_hello(Helloworld::HelloRequest.new(name: user)).message
    # p "Greeting: #{message}"
    # message = stub.say_hello_again(Helloworld::HelloRequest.new(name: user)).message
    # p "Greeting: #{message}"
  end
end

