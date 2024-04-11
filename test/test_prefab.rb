# frozen_string_literal: true

require 'test_helper'

class TestPrefab < Minitest::Test
  def test_get
    init_once

    assert_equal 'default', Prefab.get('does.not.exist', 'default')
    assert_equal 'default', Prefab.get('does.not.exist', 'default', { some: { key: 'value' } })
    assert_equal 'test sample value', Prefab.get('sample')
    assert_equal 123, Prefab.get('sample_int')

    ctx = { user: { key: 'jimmy' } }
    assert_equal 'default-goes-here', Prefab.get('user_key_match', 'default-goes-here', ctx)

    ctx = { user: { key: 'abc123' } }
    assert_equal true, Prefab.get('user_key_match', nil, ctx)
  end

  def test_defined
    init_once

    refute Prefab.defined?('does_not_exist')
    assert Prefab.defined?('sample_int')
    assert Prefab.defined?('disabled_flag')
  end

  def test_is_ff
    init_once

    assert Prefab.is_ff?('flag_with_a_value')
    refute Prefab.is_ff?('sample_int')
    refute Prefab.is_ff?('does_not_exist')
  end

  private

  def init_once
    unless Prefab.instance_variable_get("@singleton")
      Prefab.init(prefab_options)
    end
  end
end
