require 'test_helper'

class TestConfigResolver < Minitest::Test

  def test_resolution
    @loader = MockConfigLoader.new

    loaded_values = {
      "key" => Prefab::ConfigDelta.new(
        key: "key",
        default: Prefab::ConfigValue.new(string: "value_no_env_default"),
        envs: [{
                 environment: "test",
                 default: Prefab::ConfigValue.new(string: "value_none"),
                 namespace_values: [
                   {
                     namespace: "projectA",
                     config_value: Prefab::ConfigValue.new(string: "valueA")
                   },
                   {
                     namespace: "projectB",
                     config_value: Prefab::ConfigValue.new(string: "valueB")
                   },
                   {
                     namespace: "projectB.subprojectX",
                     config_value: Prefab::ConfigValue.new(string: "projectB.subprojectX")
                   },
                   {
                     namespace: "projectB.subprojectY",
                     config_value: Prefab::ConfigValue.new(string: "projectB.subprojectY")
                   },
                 ]
               }]
      ),
      "key2" => Prefab::ConfigDelta.new(
        key: "key2",
        default: Prefab::ConfigValue.new(string: "valueB2"),
      )
    }

    @loader.stub :calc_config, loaded_values do

      @resolverA = resolver_for_namespace("", @loader, environment: "some_other_env")
      assert_equal "value_no_env_default", @resolverA.get("key")

      ## below here in the test env
      @resolverA = resolver_for_namespace("", @loader)
      assert_equal "value_none", @resolverA.get("key")

      @resolverA = resolver_for_namespace("projectA", @loader)
      assert_equal "valueA", @resolverA.get("key")

      @resolverB = resolver_for_namespace("projectB", @loader)
      assert_equal "valueB", @resolverB.get("key")

      @resolverBX = resolver_for_namespace("projectB.subprojectX", @loader)
      assert_equal "projectB.subprojectX", @resolverBX.get("key")

      @resolverBX = resolver_for_namespace("projectB.subprojectX", @loader)
      assert_equal "valueB2", @resolverBX.get("key2")

      @resolverUndefinedSubProject = resolver_for_namespace("projectB.subprojectX.subsubQ", @loader)
      assert_equal "projectB.subprojectX", @resolverBX.get("key")

      @resolverBX = resolver_for_namespace("projectC", @loader)
      assert_equal "value_none", @resolverBX.get("key")
      assert_nil @resolverBX.get("key_that_doesnt_exist")
    end
  end

  def test_starts_with_ns
    @loader = MockConfigLoader.new
    @loader.stub :calc_config, {} do
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new, @loader)
      assert_equal [true, 0], resolver.send(:starts_with_ns?, "", "a")
      assert_equal [true, 1], resolver.send(:starts_with_ns?, "a", "a")
      assert_equal [true, 1], resolver.send(:starts_with_ns?, "a", "a.b")
      assert_equal [false, 2], resolver.send(:starts_with_ns?, "a.b", "a")

      assert_equal [true, 1], resolver.send(:starts_with_ns?, "corp", "corp.proj.proja")
      assert_equal [true, 2], resolver.send(:starts_with_ns?, "corp.proj", "corp.proj.proja")
      assert_equal [true, 3], resolver.send(:starts_with_ns?, "corp.proj.proja", "corp.proj.proja")
      assert_equal [false, 3], resolver.send(:starts_with_ns?, "corp.proj.projb", "corp.proj.proja")

      # corp_equal [true, 1:,a:b is not a real delimited namespace[0
      assert_equal [false, 1], resolver.send(:starts_with_ns?, "corp", "corp:a:b")
      assert_equal [true, 1], resolver.send(:starts_with_ns?, "foo", "foo.baz")
      assert_equal [true, 2], resolver.send(:starts_with_ns?, "foo.baz", "foo.baz")
      assert_equal [false, 2], resolver.send(:starts_with_ns?, "foo.baz", "foo.bazz")
    end
  end

  # colons are not allowed in keys, but verify behavior anyway
  def test_key_and_namespaces_with_colons
    @loader = MockConfigLoader.new

    loaded_values = {
      "Key:With:Colons" => Prefab::ConfigDelta.new(
        key: "Key:With:Colons",
        default: Prefab::ConfigValue.new(string: "value"),
      ),
      "proj:apikey" => Prefab::ConfigDelta.new(
        key: "proj:apikey",
        default: Prefab::ConfigValue.new(string: "v2"),
        )
    }


    @loader.stub :calc_config, loaded_values do

      r = resolver_for_namespace("foo", @loader)
      assert_nil r.get("apikey")

      r = resolver_for_namespace("proj", @loader)
      assert_nil r.get("apikey")

      r = resolver_for_namespace("", @loader)
      assert_nil r.get("apikey")

      @resolverKeyWith = resolver_for_namespace("Ket:With", @loader)
      assert_nil @resolverKeyWith.get("Colons")
      assert_nil @resolverKeyWith.get("With:Colons")
      assert_equal "value", @resolverKeyWith.get("Key:With:Colons")

      @resolverKeyWithExtra = resolver_for_namespace("Key:With:Extra", @loader)
      puts @resolverKeyWithExtra.to_s
      assert_nil @resolverKeyWithExtra.get("Colons")
      assert_nil @resolverKeyWithExtra.get("With:Colons")
      assert_equal "value", @resolverKeyWithExtra.get("Key:With:Colons")

      @resolverKey = resolver_for_namespace("Key", @loader)
      assert_nil @resolverKey.get("With:Colons")
      assert_nil @resolverKey.get("Colons")
      assert_equal "value", @resolverKey.get("Key:With:Colons")

      @resolverWithProperlySegmentedNamespace = resolver_for_namespace("Key.With.Extra", @loader)
      assert_nil @resolverWithProperlySegmentedNamespace.get("Colons")
      assert_nil @resolverWithProperlySegmentedNamespace.get("With:Colons")
      assert_equal "value", @resolverWithProperlySegmentedNamespace.get("Key:With:Colons")
    end
  end

  def resolver_for_namespace(namespace, loader, environment: "test")
    Prefab::ConfigResolver.new(MockBaseClient.new(namespace: namespace, environment: environment), loader)
  end

end
