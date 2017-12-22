class Retry
  DEFAULT_TIMEOUT = 10
  MAX_SLEEP_SEC = 10
  BASE_SLEEP_SEC = 0.5

  # GRPC Generally handles timeouts for us
  # but if the connection is broken we want to retry up until the timeout
  def self.it(stub_factory, rpc, req, timeout)
    attempts = 0
    start_time = Time.now

    begin
      attempts += 1

      return stub_factory.call.send(rpc, req)
    rescue => exception
      raise exception if Time.now - start_time > timeout

      sleep_seconds = [BASE_SLEEP_SEC * (2 ** (attempts - 1)), MAX_SLEEP_SEC].min
      sleep_seconds = sleep_seconds * (0.5 * (1 + rand()))
      sleep_seconds = [BASE_SLEEP_SEC, sleep_seconds].max
      sleep sleep_seconds
      retry
    end
  end
end
