# frozen_string_literal: true

require 'test_helper'

class TestOptions < Minitest::Test
  API_KEY = 'abcdefg'

  def test_works_with_named_arguments
    assert_equal API_KEY, Prefab::Options.new(api_key: API_KEY).api_key
  end

  def test_works_with_hash
    assert_equal API_KEY, Prefab::Options.new({ api_key: API_KEY }).api_key
  end
end
