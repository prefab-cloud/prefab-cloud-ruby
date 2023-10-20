# frozen_string_literal: true

require 'test_helper'

class TestLoggerInitialization < Minitest::Test

  def test_init_out_of_order
    # assert nothing blows up
    Prefab::LoggerClient.instance.info "anything"
  end

end
