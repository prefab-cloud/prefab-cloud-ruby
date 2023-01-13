# frozen_string_literal: true

module Prefab
  class AuthInterceptor < GRPC::ClientInterceptor
    VERSION = File.exist?('VERSION') ? File.read('VERSION').chomp : ""
    CLIENT = "prefab-cloud-ruby.#{VERSION}".freeze

    def initialize(api_key)
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
      metadata['client'] = CLIENT
      yield
    end
  end
end
