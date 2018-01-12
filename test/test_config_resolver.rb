require 'test_helper'

class TestConfigResolver < Minitest::Test

  def test_resolution
    @loader = MockConfigLoader.new

    loaded_values = {
      "projectA:key" => Prefab::ConfigValue.new(string: "valueA"),
      "key" => Prefab::ConfigValue.new(string: "value_none"),
      "projectB:key" => Prefab::ConfigValue.new(string: "valueB"),
      "projectB.subprojectX:key" => Prefab::ConfigValue.new(string: "projectB.subprojectX"),
      "projectB.subprojectY:key" => Prefab::ConfigValue.new(string: "projectB.subprojectY"),
      "projectB:key2" => Prefab::ConfigValue.new(string: "valueB2")
    }

    @loader.stub :calc_config, loaded_values do
      @resolver = Prefab::ConfigResolver.new(MockBaseClient.new, @loader)
      assert_equal "value_none", @resolver.get("key")


      @resolverA = resolver_for_namespace("projectA", @loader)
      assert_equal "valueA", @resolverA.get("key")

      @resolverB = resolver_for_namespace("projectB", @loader)
      assert_equal "valueB", @resolverB.get("key")

      @resolverBX = resolver_for_namespace("projectB.subprojectX", @loader)
      assert_equal "projectB.subprojectX", @resolverBX.get("key")

      @resolverUndefinedSubProject = resolver_for_namespace("projectB.subprojectX:subsubQ", @loader)
      assert_equal "projectB.subprojectX", @resolverBX.get("key")

      @resolverBX = resolver_for_namespace("projectC", @loader)
      assert_equal "value_none", @resolverBX.get("key")
      assert_nil @resolverBX.get("key_that_doesnt_exist")
    end
  end

  def resolver_for_namespace(namespace, loader)
    Prefab::ConfigResolver.new(MockBaseClient.new(namespace: namespace), loader)
  end

end
