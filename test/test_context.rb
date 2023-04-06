# frozen_string_literal: true

require 'test_helper'

class TestContext < Minitest::Test
  EXAMPLE_PROPERTIES = { user: { key: 'some-user-key', name: 'Ted' }, team: { key: 'abc', plan: 'pro' } }.freeze

  def setup
    Prefab::Context.current = nil
  end

  def test_initialize_with_empty_context
    context = Prefab::Context.new({})
    assert_empty context.contexts
  end

  def test_initialize_with_named_context
    named_context = Prefab::Context::NamedContext.new('test', foo: 'bar')
    context = Prefab::Context.new(named_context)
    assert_equal 1, context.contexts.size
    assert_equal named_context, context.contexts['test']
  end

  def test_initialize_with_hash
    context = Prefab::Context.new(test: { foo: 'bar' })
    assert_equal 1, context.contexts.size
    assert_equal 'bar', context.contexts['test'].get('foo')
  end

  def test_initialize_with_multiple_hashes
    context = Prefab::Context.new(test: { foo: 'bar' }, other: { foo: 'baz' })
    assert_equal 2, context.contexts.size
    assert_equal 'bar', context.contexts['test'].get('foo')
    assert_equal 'baz', context.contexts['other'].get('foo')
  end

  def test_initialize_with_invalid_hash
    assert_raises(ArgumentError) do
      context = Prefab::Context.new({ foo: 'bar', baz: 'qux' })
    end
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
      assert_equal('some-user-key', context['user.key'])
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

  def test_setting
    context = Prefab::Context.new({})
    context.set('user', { key: 'value' })
    context[:other] = { key: 'different', something: 'other' }
    assert_equal(stringify({ user: { key: 'value' }, other: { key: 'different', something: 'other' } }), context.to_h)
  end

  def test_getting
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    assert_equal('some-user-key', context.get('user.key'))
    assert_equal('some-user-key', context['user.key'])
    assert_equal('pro', context.get('team.plan'))
    assert_equal('pro', context['team.plan'])
  end

  def test_dot_notation_getting
    context = Prefab::Context.new({ 'user' => { 'key' => 'value' } })
    assert_equal('value', context.get('user.key'))
    assert_equal('value', context['user.key'])
  end

  def test_dot_notation_getting_with_symbols
    context = Prefab::Context.new({ user: { key: 'value' } })
    assert_equal('value', context.get('user.key'))
    assert_equal('value', context['user.key'])
  end

  def test_merge
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    context.merge!(:other, { key: 'different' })
    assert_equal(stringify(EXAMPLE_PROPERTIES.merge(other: { key: 'different' })), context.to_h)
  end

  def test_clear
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    context.clear

    assert_empty context.to_h
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
