class Retry
  MAX_SLEEP_SEC = 10
  BASE_SLEEP_SEC = 0.5

  # GRPC Generally handles timeouts for us
  # but if the connection is broken we want to retry up until the timeout
  def self.it(stub_factory, rpc, req, timeout, reset)
    attempts = 0
    start_time = Time.now

    begin
      attempts += 1
      return stub_factory.call.send(rpc, req)
    rescue => exception

      if Time.now - start_time > timeout
        raise exception
      end
      sleep_seconds = [BASE_SLEEP_SEC * (2 ** (attempts - 1)), MAX_SLEEP_SEC].min
      sleep_seconds = sleep_seconds * (0.5 * (1 + rand()))
      sleep_seconds = [BASE_SLEEP_SEC, sleep_seconds].max
      puts "Sleep #{sleep_seconds} and Reset"
      sleep sleep_seconds
      reset.call
      retry
    end
  end
end
