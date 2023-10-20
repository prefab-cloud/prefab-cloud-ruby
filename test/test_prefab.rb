# frozen_string_literal: true

require 'test_helper'

class TestPrefab < Minitest::Test
  def test_get
    Prefab.init(prefab_options)
    assert_equal 'default', Prefab.get('does.not.exist', 'default')
    assert_equal 'test sample value', Prefab.get('sample')
    assert_equal 123, Prefab.get('sample_int')
  end
end
