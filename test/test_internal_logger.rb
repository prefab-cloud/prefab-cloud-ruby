# frozen_string_literal: true

require 'test_helper'

class TestInternalLogger < Minitest::Test

  def test_levels
    logger_a = Prefab::InternalLogger.new(A)
    logger_b = Prefab::InternalLogger.new(B)

    assert_equal :warn, logger_a.level
    assert_equal :warn, logger_b.level

    Prefab::InternalLogger.using_prefab_log_filter!
    assert_equal :trace, logger_a.level
    assert_equal :trace, logger_b.level
  end

end

class A
end

class B
end
