require 'test_helper'

class TestConfigLoader < Minitest::Test
  def setup
    ENV['PREFAB_CONFIG_OVERRIDE_DIR'] = "none"
    ENV['PREFAB_CONFIG_CLASSPATH_DIR'] = "test"
    @loader = Prefab::ConfigLoader.new(MockBaseClient.new)
  end

  def test_load
    should_be :int, 123, "sample_int"
    should_be :string, "OneTwoThree", "sample"
    should_be :bool, true, "sample_bool"
    should_be :double, 12.12, "sample_double"
  end


  def test_api_precedence
    should_be :int, 123, "sample_int"

    @loader.set(Prefab::ConfigDelta.new(key: "sample_int", value: Prefab::ConfigValue.new(int: 456)))
    should_be :int, 456, "sample_int"

  end

  def test_api_deltas
    val = Prefab::ConfigValue.new(int: 456)
    delta = Prefab::ConfigDelta.new(key: "sample_int", value: val)
    @loader.set(delta)

    deltas = Prefab::ConfigDeltas.new
    deltas.deltas << delta
    assert_equal deltas, @loader.get_api_deltas
  end

  private

  def should_be(type, value, key)
    assert_equal type, @loader.calc_config[key].type
    assert_equal value, @loader.calc_config[key].send(type)
  end

end
