# frozen_string_literal: true

module Prefab
  class QueuedLoggerClient < LoggerClient
    def initialize(logdev, log_path_collector: nil, formatter: nil, prefix: nil)
      super

      @trace_lookup = Concurrent::Hash.new
    end

    def log(message, path, progname, severity)
      return if @silences[local_log_id]

      time = Time.now
      context = Prefab::Context.current

      @trace_lookup[trace_id] ||= Queue.new
      @trace_lookup[trace_id].push lambda {
        Prefab::Context.with_context(context) do
          super(message, path, progname, severity, time)
        end
      }
    end

    def release(provided_trace_id = nil, error: false)
      queue = @trace_lookup.delete(provided_trace_id || trace_id)

      return if queue.nil?

      error_context = { "prefab-runtime" => { "error-occurred" => error } }

      Prefab::Context.with_context(error_context) do
        # We reject silenced logs at `#log` time so _don't_ want them to be
        # subject to the current @silences here
        unsilence do
          queue.pop.call until queue.empty?
        end
      end
    end

    def discard(provided_trace_id = nil)
      @trace_lookup.delete(provided_trace_id || trace_id)
    end

    def set_trace_id(trace_id)
      Thread.current[:queued_logger_trace_id] = trace_id
    end

    def trace_id
      Thread.current[:queued_logger_trace_id] || Thread.current.__id__
    end
  end
end
