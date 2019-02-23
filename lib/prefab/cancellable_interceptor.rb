module Prefab
  class CancellableInterceptor < GRPC::ClientInterceptor

    def cancel
      @call.instance_variable_get("@wrapped").instance_variable_get("@call").cancel
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
