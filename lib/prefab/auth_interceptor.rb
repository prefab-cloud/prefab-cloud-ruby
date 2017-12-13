class AuthInterceptor < GRPC::ClientInterceptor
  def initialize(api_key)
    @api_key = api_key
  end

  def request_response(request:, call:, method:, metadata:)
    metadata['auth'] = @api_key
    yield
  end

  def client_streamer(requests:, call:, method:, metadata:)
    metadata['auth'] = @api_key
    yield
  end

  def server_streamer(request:, call:, method:, metadata:)
    metadata['auth'] = @api_key
    yield
  end

  def bidi_streamer(requests:, call:, method:, metadata:)
    metadata['auth'] = @api_key
    yield
  end
end
