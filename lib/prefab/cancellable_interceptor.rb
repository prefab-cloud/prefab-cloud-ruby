module Prefab
  class CancellableInterceptor < GRPC::ClientInterceptor
    WAIT_SEC = 3

    def initialize(base_client)
      @base_client = base_client
    end

    def cancel
      @call.instance_variable_get("@wrapped").instance_variable_get("@call").cancel
      i = 0
      while (i < WAIT_SEC) do
        if @call.instance_variable_get("@wrapped").cancelled?
          @base_client.log_internal Logger::DEBUG, "Cancelled streaming."
          return
        else
          @base_client.log_internal Logger::DEBUG, "Unable to cancel streaming. Trying again"
          @call.instance_variable_get("@wrapped").instance_variable_get("@call").cancel
          i += 1
          sleep(1)
        end
      end
      @base_client.log_internal Logger::INFO, "Unable to cancel streaming."
    end

    def request_response(request:, call:, method:, metadata:, &block)
      shared(call, &block)
    end

    def client_streamer(requests:, call:, method:, metadata:, &block)
      shared(call, &block)
    end

    def server_streamer(request:, call:, method:, metadata:, &block)
      shared(call, &block)
    end

    def bidi_streamer(requests:, call:, method:, metadata:, &block)
      shared(call, &block)
    end

    def shared(call)
      @call = call
      yield
    end
  end
end
