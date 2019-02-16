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

  def test_starts_with_ns
    @loader = MockConfigLoader.new
    @loader.stub :calc_config, {} do
      resolver = Prefab::ConfigResolver.new(MockBaseClient.new, @loader)
      assert resolver.send(:starts_with_ns?, "", "a")
      assert resolver.send(:starts_with_ns?, "a", "a")
      assert resolver.send(:starts_with_ns?, "a", "a.b")
      assert !resolver.send(:starts_with_ns?, "a.b", "a")

      assert resolver.send(:starts_with_ns?, "corp", "corp.proj.proja")
      assert resolver.send(:starts_with_ns?, "corp.proj", "corp.proj.proja")
      assert resolver.send(:starts_with_ns?, "corp.proj.proja", "corp.proj.proja")
      assert !resolver.send(:starts_with_ns?, "corp.proj.projb", "corp.proj.proja")

      # corp:a:b is not a real delimited namespace
      assert !resolver.send(:starts_with_ns?, "corp", "corp:a:b")
      assert resolver.send(:starts_with_ns?, "foo", "foo.baz")
      assert resolver.send(:starts_with_ns?, "foo.baz", "foo.baz")
      assert !resolver.send(:starts_with_ns?, "foo.baz", "foo.bazz")
    end
  end

  # colons are not allowed in keys, but verify behavior anyway
  def test_keys_with_colons
    @loader = MockConfigLoader.new
    loaded_values = {
      "Key:With:Colons" => Prefab::ConfigValue.new(string: "value"),
      "proj:apikey" => Prefab::ConfigValue.new(string: "v2")
    }

    @loader.stub :calc_config, loaded_values do

      r = resolver_for_namespace("foo", @loader)
      assert_nil r.get("apikey")

      r = resolver_for_namespace("proj", @loader)
      assert_equal "v2", r.get("apikey")

      r = resolver_for_namespace("", @loader)
      assert_nil r.get("apikey")


      @resolverKeyWith = resolver_for_namespace("Ket:With", @loader)
      assert_nil @resolverKeyWith.get("Colons")
      assert_nil @resolverKeyWith.get("With:Colons")
      assert_nil @resolverKeyWith.get("Key:With:Colons")

      @resolverKeyWithExtra = resolver_for_namespace("Key:With:Extra", @loader)
      puts @resolverKeyWithExtra.to_s
      assert_nil @resolverKeyWithExtra.get("Colons")
      assert_nil @resolverKeyWithExtra.get("With:Colons")
      assert_nil @resolverKeyWithExtra.get("Key:With:Colons")

      @resolverKey = resolver_for_namespace("Key", @loader)
      assert_equal "value", @resolverKey.get("With:Colons")
      assert_nil @resolverKey.get("Colons")
      assert_nil @resolverKey.get("Key:With:Colons")

      @resolverWithProperlySegmentedNamespace = resolver_for_namespace("Key.With.Extra", @loader)
      assert_nil @resolverWithProperlySegmentedNamespace.get("Colons")
      assert_equal "value", @resolverWithProperlySegmentedNamespace.get("With:Colons")
      assert_nil @resolverWithProperlySegmentedNamespace.get("Key:With:Colons")
    end
  end

  def resolver_for_namespace(namespace, loader)
    Prefab::ConfigResolver.new(MockBaseClient.new(namespace: namespace), loader)
  end

end
