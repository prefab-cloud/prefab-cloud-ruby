# frozen_string_literal: true

class IntegrationTest
  attr_reader :func, :input, :expected, :data, :expected_data, :aggregator, :test_client

  def initialize(test_data)
    @client_overrides = parse_client_overrides(test_data['client_overrides'])
    @func = parse_function(test_data['function'])
    @input = parse_input(test_data['input'])
    @expected = parse_expected(test_data['expected'])
    @data = test_data['data']
    @expected_data = test_data['expected_data']
    @aggregator = test_data['aggregator']
    @test_client = base_client
  end

  def test_type
    if @data
      :telemetry
    elsif @input[0] && @input[0].start_with?('log-level.')
      :log_level
    elsif @expected[:status] == 'raise'
      :raise
    elsif @expected[:value].nil?
      :nil
    else
      :simple_equality
    end
  end

  private

  def parse_client_overrides(overrides)
    Hash[
      (overrides || {}).map do |(k, v)|
        [k.to_sym, v]
      end
    ]
  end

  def parse_function(function)
    case function
    when 'get_or_raise' then :get
    when 'enabled' then :enabled?
    else :"#{function}"
    end
  end

  def parse_input(input)
    return nil if input.nil?
    if input['key']
      parse_config_input(input)
    elsif input['flag']
      parse_ff_input(input)
    end
  end

  def parse_config_input(input)
    if !input['default'].nil?
      [input['key'], input['default']]
    else
      [input['key']]
    end
  end

  def parse_ff_input(input)
    [input['flag'], input['default'], input['context']]
  end

  def parse_expected(expected)
    return {} if expected.nil?
    {
      status: expected['status'],
      error: parse_error_type(expected['error']),
      message: expected['message'],
      value: expected['value']
    }
  end

  def parse_error_type(error_type)
    case error_type
    when 'missing_default' then Prefab::Errors::MissingDefaultError
    when 'initialization_timeout' then Prefab::Errors::InitializationTimeoutError
    end
  end

  def base_client
    @_base_client ||= Prefab::Client.new(base_client_options)
  end

  def base_client_options
    @_options ||= Prefab::Options.new(**{
      prefab_config_override_dir: 'none',
      prefab_config_classpath_dir: 'test',
      prefab_envs: ['unit_tests'],
      prefab_datasources: Prefab::Options::DATASOURCES::ALL,
      api_key: ENV['PREFAB_INTEGRATION_TEST_API_KEY'],
      prefab_api_url: 'https://api.staging-prefab.cloud',
    }.merge(@client_overrides))
  end
end
