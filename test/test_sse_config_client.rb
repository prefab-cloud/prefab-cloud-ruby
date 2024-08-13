require 'test_helper'

class TestSSEConfigClient < Minitest::Test
  def test_client
    sources = [
      "https://api.staging-prefab.cloud/",
    ]

    options = Prefab::Options.new(sources: sources, api_key: ENV['PREFAB_INTEGRATION_TEST_API_KEY'])

    config_loader = OpenStruct.new(highwater_mark: 4)

    client = Prefab::SSEConfigClient.new(options, config_loader)

    assert_equal 4, client.headers['x-prefab-start-at-id']

    result = nil

    # fake our load_configs block
    client.start do |c, source|
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
      "https://does.not.exist.staging-prefab.cloud/",
      "https://api.staging-prefab.cloud/",
    ]

    options = Prefab::Options.new(sources: sources, api_key: ENV['PREFAB_INTEGRATION_TEST_API_KEY'])

    config_loader = OpenStruct.new(highwater_mark: 4)

    client = Prefab::SSEConfigClient.new(options, config_loader)

    assert_equal 4, client.headers['x-prefab-start-at-id']

    result = nil

    # fake our load_configs block
    client.start do |c, source|
      result = c
      assert_equal :sse, source
    end

    wait_for -> { !result.nil? }, max_wait: 10

    assert result.configs.size > 30
  ensure
    client.close

    assert_logged [
      /failed to connect: .*https:\/\/does.not.exist/,
      /HTTP::ConnectionError/,
    ]
  end
end
