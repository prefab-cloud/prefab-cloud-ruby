# frozen_string_literal: true

module Prefab
  class HttpConnection
    AUTH_USER = 'authuser'
    PROTO_HEADERS = {
      'Content-Type' => 'application/x-protobuf',
      'Accept' => 'application/x-protobuf',
      'X-PrefabCloud-Client-Version' => "prefab-cloud-ruby-#{Prefab::VERSION}"
    }.freeze

    def initialize(api_root, api_key)
      @api_root = api_root
      @api_key = api_key
    end

    def get(path)
      connection.get(path)
    end

    def post(path, body)
      connection(PROTO_HEADERS).post(path, body.to_proto)
    end

    def connection(headers = {})
      if Faraday::VERSION[0].to_i >= 2
        Faraday.new(@api_root) do |conn|
          conn.request :authorization, :basic, AUTH_USER, @api_key

          conn.headers.merge!(headers)
        end
      else
        Faraday.new(@api_root) do |conn|
          conn.request :basic_auth, AUTH_USER, @api_key

          conn.headers.merge!(headers)
        end
      end
    end
  end
end
