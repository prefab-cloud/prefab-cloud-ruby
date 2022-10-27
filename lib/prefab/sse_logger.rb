# frozen_string_literal: true
module Prefab
  class SseLogger < InternalLogger
    def initialize(logger)
      super("cloud.prefab.config.sse", logger)
    end

    # The SSE::Client warns on a perfectly normal stream disconnect, recast to info
    def warn(progname = nil, &block)
      @logger.log_internal yield, @path, progname, INFO
    end
  end
end
