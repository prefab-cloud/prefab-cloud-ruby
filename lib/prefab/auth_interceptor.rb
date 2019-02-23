module Prefab
  class AuthInterceptor < GRPC::ClientInterceptor
    def initialize(api_key)
      version = File.exist?('VERSION') ? File.read('VERSION').chomp : ""
      @client = "prefab-cloud-ruby.#{version}".freeze
      @api_key = api_key
    end

    def request_response(request:, call:, method:, metadata:, &block)
      shared(metadata, &block)
    end

    def client_streamer(requests:, call:, method:, metadata:, &block)
      shared(metadata, &block)
    end

    def server_streamer(request:, call:, method:, metadata:, &block)
      shared(metadata, &block)
    end

    def bidi_streamer(requests:, call:, method:, metadata:, &block)
      shared(metadata, &block)
    end

    def shared(metadata)
      metadata['auth'] = @api_key
      metadata['client'] = @client
      yield
    end
  end
end
