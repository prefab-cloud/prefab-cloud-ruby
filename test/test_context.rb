# frozen_string_literal: true

require 'test_helper'

class TestContext < Minitest::Test
  EXAMPLE_PROPERTIES = { user: { key: 'some-user-key', name: 'Ted' }, team: { key: 'abc', plan: 'pro' } }.freeze

  def setup
    super
    Prefab::Context.current = nil
  end

  def test_initialize_with_empty_context
    context = Prefab::Context.new({})
    assert_empty context.contexts
  end

  def test_initialize_with_hash
    context = Prefab::Context.new(test: { foo: 'bar' })
    assert_equal 1, context.contexts.size
    assert_equal 'bar', context.get("test.foo")
  end

  def test_initialize_with_multiple_hashes
    context = Prefab::Context.new(test: { foo: 'bar' }, other: { foo: 'baz' })
    assert_equal 2, context.contexts.size
    assert_equal 'bar', context.get("test.foo")
    assert_equal 'baz', context.get("other.foo")
  end

  def test_initialize_with_invalid_argument
    assert_raises(ArgumentError) { Prefab::Context.new([]) }
  end

  def test_current
    context = Prefab::Context.current
    assert_instance_of Prefab::Context, context
    assert_empty context.to_h
  end

  def test_current_set
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    Prefab::Context.current = context
    assert_instance_of Prefab::Context, context
    assert_equal stringify(EXAMPLE_PROPERTIES), context.to_h
  end

  def test_with_context
    Prefab::Context.with_context(EXAMPLE_PROPERTIES) do
      context = Prefab::Context.current
      assert_equal(stringify(EXAMPLE_PROPERTIES), context.to_h)
      assert_equal('some-user-key', context.get('user.key'))
    end
  end

  def test_with_context_nesting
    Prefab::Context.with_context(EXAMPLE_PROPERTIES) do
      Prefab::Context.with_context({ user: { key: 'abc', other: 'different' } }) do
        context = Prefab::Context.current
        assert_equal({ 'user' => { 'key' => 'abc', 'other' => 'different' } }, context.to_h)
      end

      context = Prefab::Context.current
      assert_equal(stringify(EXAMPLE_PROPERTIES), context.to_h)
    end
  end

  def test_with_context_merge_nesting
    Prefab::Context.with_context(EXAMPLE_PROPERTIES) do
      Prefab::Context.with_merged_context({ user: { key: 'hij', other: 'different' } }) do
        context = Prefab::Context.current
        assert_equal context.get('user.name'), 'Ted'
        assert_equal context.get('user.key'), 'hij'
        assert_equal context.get('user.other'), 'different'

        assert_equal context.get('team.key'), 'abc'
        assert_equal context.get('team.plan'), 'pro'
      end

      context = Prefab::Context.current
      assert_equal(stringify(EXAMPLE_PROPERTIES), context.to_h)
    end
  end

  def test_setting
    context = Prefab::Context.new({})
    context.set('user', { key: 'value' })
    context.set(:other, { key: 'different', something: 'other' })
    assert_equal(stringify({ user: { key: 'value' }, other: { key: 'different', something: 'other' } }), context.to_h)
  end

  def test_getting
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    assert_equal('some-user-key', context.get('user.key'))
    assert_equal('pro', context.get('team.plan'))
  end

  def test_dot_notation_getting
    context = Prefab::Context.new({ 'user' => { 'key' => 'value' } })
    assert_equal('value', context.get('user.key'))
  end

  def test_dot_notation_getting_with_symbols
    context = Prefab::Context.new({ user: { key: 'value' } })
    assert_equal('value', context.get('user.key'))
  end

  def test_clear
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    context.clear

    assert_empty context.to_h
  end

  def test_to_proto
    namespace = "my.namespace"

    contexts = Prefab::Context.new({
                                     user: {
                                       id: 1,
                                       email: 'user-email'
                                     },
                                     team: {
                                       id: 2,
                                       name: 'team-name'
                                     }
                                   })

    assert_equal PrefabProto::ContextSet.new(
      contexts: [
        PrefabProto::Context.new(
          type: "user",
          values: {
            "id" => PrefabProto::ConfigValue.new(int: 1),
            "email" => PrefabProto::ConfigValue.new(string: "user-email")
          }
        ),
        PrefabProto::Context.new(
          type: "team",
          values: {
            "id" => PrefabProto::ConfigValue.new(int: 2),
            "name" => PrefabProto::ConfigValue.new(string: "team-name")
          }
        ),

        PrefabProto::Context.new(
          type: "prefab",
          values: {
            'current-time' => PrefabProto::ConfigValue.new(int: Prefab::TimeHelpers.now_in_ms),
            'namespace' => PrefabProto::ConfigValue.new(string: namespace)
          }
        )
      ]
    ), contexts.to_proto(namespace)
  end

  private

  def stringify(hash)
    hash.map { |k, v| [k.to_s, stringify_keys(v)] }.to_h
  end

  def stringify_keys(value)
    if value.is_a?(Hash)
      value.transform_keys(&:to_s)
    else
      value
    end
  end
end
