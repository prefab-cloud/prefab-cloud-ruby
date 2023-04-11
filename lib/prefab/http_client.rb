module Prefab
  class HttpClient
    def connection
      @connection ||= Faraday.new(url: @base_url) do |faraday|
        faraday.request :url_encoded
        faraday.response :logger, @logger, bodies: true
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
