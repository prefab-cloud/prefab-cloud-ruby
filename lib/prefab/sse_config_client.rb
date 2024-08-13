# frozen_string_literal: true

module Prefab
  class SSEConfigClient
    SSE_READ_TIMEOUT = 300
    SECONDS_BETWEEN_RECONNECT = 5
    AUTH_USER = 'authuser'
    LOG = Prefab::InternalLogger.new(self)

    def initialize(options, config_loader)
      @options = options
      @config_loader = config_loader
      @connected = false
    end

    def close
      @retry_thread&.kill
      @client&.close
    end

    def start(&load_configs)
      if @options.sse_sources.empty?
        LOG.debug 'No SSE sources configured'
        return
      end

      @client = connect(&load_configs)

      closed_count = 0

      @retry_thread = Thread.new do
        loop do
          sleep 1

          if @client.closed?
            closed_count += 1

            if closed_count > SECONDS_BETWEEN_RECONNECT
              closed_count = 0
              connect(&load_configs)
            end
          end
        end
      end
    end

    def connect(&load_configs)
      url = "#{source}/api/v1/sse/config"
      LOG.debug "SSE Streaming Connect to #{url} start_at #{@config_loader.highwater_mark}"

      SSE::Client.new(url,
                      headers: headers,
                      read_timeout: SSE_READ_TIMEOUT,
                      logger: Prefab::InternalLogger.new(SSE::Client)) do |client|
        client.on_event do |event|
          configs = PrefabProto::Configs.decode(Base64.decode64(event.data))
          load_configs.call(configs, :sse)
        end

        client.on_error do |error|
          LOG.error "SSE Streaming Error: #{error} for url #{url}"

          if error.is_a?(HTTP::ConnectionError)
            client.close
          end
        end
      end
    end

    def headers
      auth = "#{AUTH_USER}:#{@options.api_key}"
      auth_string = Base64.strict_encode64(auth)
      return {
        'x-prefab-start-at-id' => @config_loader.highwater_mark,
        'Authorization' => "Basic #{auth_string}",
        'Accept' => 'text/event-stream',
        'X-PrefabCloud-Client-Version' => "prefab-cloud-ruby-#{Prefab::VERSION}"
      }
    end

    def source
      @source_index = @source_index.nil? ? 0 : @source_index + 1

      if @source_index >= @options.sse_sources.size
        @source_index = 0
      end

      return @options.sse_sources[@source_index]
    end
  end
end
