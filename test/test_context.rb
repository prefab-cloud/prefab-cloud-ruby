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
    _, err = capture_io do
      Prefab::Context.new({ foo: 'bar', baz: 'qux' })
    end

    assert_match '[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash',
                 err
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

  def test_merge_with_current
    context = Prefab::Context.new(EXAMPLE_PROPERTIES)
    Prefab::Context.current = context
    assert_equal stringify(EXAMPLE_PROPERTIES), context.to_h

    new_context = Prefab::Context.merge_with_current({ user: { key: 'brand-new', other: 'different' },
                                                       address: { city: 'New York' } })
    assert_equal stringify({
                             # Note that the user's `name` from the original
                             # context is not included. This is because we don't _merge_ the new
                             # properties if they collide with an existing context name. We _replace_
                             # them.
                             user: { key: 'brand-new', other: 'different' },
                             team: EXAMPLE_PROPERTIES[:team],
                             address: { city: 'New York' }
                           }),
                 new_context.to_h

    # the original/current context is unchanged
    assert_equal stringify(EXAMPLE_PROPERTIES), Prefab::Context.current.to_h
  end

  def test_with_context
    returned = Prefab::Context.with_context(EXAMPLE_PROPERTIES) do
      context = Prefab::Context.current
      assert_equal(stringify(EXAMPLE_PROPERTIES), context.to_h)
      assert_equal('some-user-key', context.get('user.key'))

      'some-return-value'
    end

    assert_equal 'some-return-value', returned
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

  def test_printing_current_context
    # This shouldn't raise or segfault
    _, err = capture_io do
      Prefab::Context.with_context({ hi: 1 }) {}
      puts Prefab::Context.current
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
