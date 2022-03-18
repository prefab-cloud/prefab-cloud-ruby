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

  def test_highwater
    assert_equal 0, @loader.highwater_mark
    @loader.set(Prefab::Config.new(id: 1, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 456))]))
    assert_equal 1, @loader.highwater_mark

    @loader.set(Prefab::Config.new(id: 5, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 456))]))
    assert_equal 5, @loader.highwater_mark
    @loader.set(Prefab::Config.new(id: 2, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 456))]))
    assert_equal 5, @loader.highwater_mark
  end

  def test_keeps_most_recent
    assert_equal 0, @loader.highwater_mark
    @loader.set(Prefab::Config.new(id: 1, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 1))]))
    assert_equal 1, @loader.highwater_mark
    should_be :int, 1, "sample_int"

    @loader.set(Prefab::Config.new(id: 4, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 4))]))
    assert_equal 4, @loader.highwater_mark
    should_be :int, 4, "sample_int"

    @loader.set(Prefab::Config.new(id: 2, key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 2))]))
    assert_equal 4, @loader.highwater_mark
    should_be :int, 4, "sample_int"
  end

  def test_api_precedence
    should_be :int, 123, "sample_int"

    @loader.set(Prefab::Config.new(key: "sample_int", rows: [Prefab::ConfigRow.new(value: Prefab::ConfigValue.new(int: 456))]))
    should_be :int, 456, "sample_int"
  end

  def test_api_deltas
    val = Prefab::ConfigValue.new(int: 456)
    config = Prefab::Config.new(key: "sample_int", rows: [Prefab::ConfigRow.new(value: val)])
    @loader.set(config)

    configs = Prefab::Configs.new
    configs.configs << config
    assert_equal configs, @loader.get_api_deltas
  end

  def test_loading_tombstones_removes_entries
    val = Prefab::ConfigValue.new(int: 456)
    config = Prefab::Config.new(key: "sample_int", rows: [Prefab::ConfigRow.new(value: val)])
    @loader.set(config)

    config = Prefab::Config.new(key: "sample_int", rows: [])
    @loader.set(config)

    configs = Prefab::Configs.new
    assert_equal configs, @loader.get_api_deltas
  end

  private

  def should_be(type, value, key)
    assert_equal type, @loader.calc_config[key].rows[0].value.type
    assert_equal value, @loader.calc_config[key].rows[0].value.send(type)
  end

end
