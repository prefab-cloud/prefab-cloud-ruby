# frozen_string_literal: true

module Prefab
  class SseLogger < InternalLogger
    def initialize()
      super("sse")
    end

    # The SSE::Client warns on a perfectly normal stream disconnect, recast to info
    def warn(msg = nil,**log_context,  &block)
      Prefab::LoggerClient.instance.log_internal ::Logger::INFO, msg, @path, log_context, &block
    end
  end
end
