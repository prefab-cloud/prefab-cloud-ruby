# frozen_string_literal: true

require 'test_helper'
require 'webrick'

class TestSSEConfigClient < Minitest::Test
  def test_client
    sources = [
      'https://belt.staging-prefab.cloud/'
    ]

    options = Prefab::Options.new(sources: sources, api_key: ENV.fetch('PREFAB_INTEGRATION_TEST_API_KEY', nil))

    config_loader = OpenStruct.new(highwater_mark: 4)

    client = Prefab::SSEConfigClient.new(options, config_loader)

    assert_equal 4, client.headers['x-prefab-start-at-id']
    assert_equal "https://stream.staging-prefab.cloud", client.source

    result = nil

    # fake our load_configs block
    client.start do |c, _event, source|
      result = c
      assert_equal :sse, source
    end

    wait_for -> { !result.nil? }

    assert result.configs.size > 30
  ensure
    client.close
  end

  def test_failing_over
    sources = [
      'https://does.not.exist.staging-prefab.cloud/',
      'https://api.staging-prefab.cloud/'
    ]

    prefab_options = Prefab::Options.new(sources: sources, api_key: ENV.fetch('PREFAB_INTEGRATION_TEST_API_KEY', nil))

    config_loader = OpenStruct.new(highwater_mark: 4)

    sse_options = Prefab::SSEConfigClient::Options.new(seconds_between_new_connection: 0.01, sleep_delay_for_new_connection_check: 0.01)

    client = Prefab::SSEConfigClient.new(prefab_options, config_loader, sse_options)

    assert_equal 4, client.headers['x-prefab-start-at-id']

    result = nil

    # fake our load_configs block
    client.start do |c, _event, source|
      result = c
      assert_equal :sse, source
    end

    wait_for -> { !result.nil? }

    assert result.configs.size > 30
  ensure
    client.close

    assert_logged [
      %r{failed to connect: .*https://does.not.exist},
      /HTTP::ConnectionError/
    ]
  end

  def test_recovering_from_disconnection
    server, = start_webrick_server(4567, DisconnectingEndpoint)

    config_loader = OpenStruct.new(highwater_mark: 4)

    prefab_options = OpenStruct.new(sse_sources: ['http://localhost:4567'], api_key: 'test')
    last_event_id = nil
    client = nil

    begin
      Thread.new do
        server.start
      end

      sse_options = Prefab::SSEConfigClient::Options.new(
        sse_default_reconnect_time: 0.1
      )
      client = Prefab::SSEConfigClient.new(prefab_options, config_loader, sse_options)

      client.start do |_configs, event, _source|
        last_event_id = event.id.to_i
      end

      wait_for -> { last_event_id && last_event_id > 1 }
    ensure
      client.close
      server.stop

      refute_nil last_event_id, 'Expected to have received an event'
      assert last_event_id > 1, 'Expected to have received multiple events (indicating a retry)'
    end
  end

  def test_recovering_from_an_error
    log_output = StringIO.new
    logger = Logger.new(log_output)

    server, = start_webrick_server(4568, ErroringEndpoint)

    config_loader = OpenStruct.new(highwater_mark: 4)

    prefab_options = OpenStruct.new(sse_sources: ['http://localhost:4568'], api_key: 'test')
    last_event_id = nil
    client = nil

    begin
      Thread.new do
        server.start
      end

      sse_options = Prefab::SSEConfigClient::Options.new(
        sse_default_reconnect_time: 0.1,
        seconds_between_new_connection: 0.1,
        sleep_delay_for_new_connection_check: 0.1,
        errors_to_close_connection: [SSE::Errors::HTTPStatusError]
      )
      client = Prefab::SSEConfigClient.new(prefab_options, config_loader, sse_options, logger)

      client.start do |_configs, event, _source|
        last_event_id = event.id.to_i
      end

      wait_for -> { last_event_id && last_event_id > 2 }
    ensure
      server.stop
      client.close

      refute_nil last_event_id, 'Expected to have received an event'
      assert last_event_id > 2, 'Expected to have received multiple events (indicating a reconnect)'
    end

    log_lines = log_output.string.split("\n")

    assert_match(/SSE Streaming Connect/, log_lines[0])
    assert_match(/SSE Streaming Error/, log_lines[1], 'Expected to have logged an error. If this starts failing after an ld-eventsource upgrade, you might need to tweak NUMBER_OF_FAILURES below')
    assert_match(/Closing SSE connection/, log_lines[2])
    assert_match(/Reconnecting SSE client/, log_lines[3])
    assert_match(/SSE Streaming Connect/, log_lines[4])
  end

  def start_webrick_server(port, endpoint_class)
    log_string = StringIO.new
    logger = WEBrick::Log.new(log_string)
    server = WEBrick::HTTPServer.new(Port: port, Logger: logger, AccessLog: [])
    server.mount '/api/v1/sse/config', endpoint_class

    [server, log_string]
  end

  module SharedEndpointLogic
    def event_id
      @@event_id ||= 0
      @@event_id += 1
    end

    def setup_response(response)
      response.status = 200
      response['Content-Type'] = 'text/event-stream'
      response['Cache-Control'] = 'no-cache'
      response['Connection'] = 'keep-alive'

      response.chunked = false
    end
  end

  class DisconnectingEndpoint < WEBrick::HTTPServlet::AbstractServlet
    include SharedEndpointLogic

    def do_GET(_request, response)
      setup_response(response)

      output = response.body

      output << "id: #{event_id}\n"
      output << "event: message\n"
      output << "data: CmYIu8fh4YaO0x4QZBo0bG9nLWxldmVsLmNsb3VkLnByZWZhYi5zZXJ2ZXIubG9nZ2luZy5FdmVudFByb2Nlc3NvciIfCAESG2phbWVzLmtlYmluZ2VyQHByZWZhYi5jbG91ZDgGSAkSDQhkELvH4eGGjtMeGGU=\n\n"
    end
  end

  class ErroringEndpoint < WEBrick::HTTPServlet::AbstractServlet
    include SharedEndpointLogic
    NUMBER_OF_FAILURES = 5

    def do_GET(_request, response)
      setup_response(response)

      output = response.body

      output << "id: #{event_id}\n"

      if event_id < NUMBER_OF_FAILURES
        raise 'ErroringEndpoint' # This manifests as an SSE::Errors::HTTPStatusError
      end

      output << "event: message\n"
      output << "data: CmYIu8fh4YaO0x4QZBo0bG9nLWxldmVsLmNsb3VkLnByZWZhYi5zZXJ2ZXIubG9nZ2luZy5FdmVudFByb2Nlc3NvciIfCAESG2phbWVzLmtlYmluZ2VyQHByZWZhYi5jbG91ZDgGSAkSDQhkELvH4eGGjtMeGGU=\n\n"
    end
  end
end
