# frozen_string_literal: true

class MockConfigClient
  def initialize(config_values = {})
    @config_values = config_values
  end

  def get(key, default = nil)
    @config_values.fetch(key, default)
  end

  def get_config(key)
    PrefabProto::Config.new(value: @config_values[key], key: key)
  end

  def mock_this_config(key, config_value)
    @config_values[key] = config_value
  end
end
