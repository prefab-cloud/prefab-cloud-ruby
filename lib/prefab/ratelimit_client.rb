module Prefab
  class RateLimitClient

    def initialize(client, timeout)
      @timeout = timeout
      @client = client
    end

    def pass?(group)
      result = acquire([group], 1)
      return result.passed
    end

    def acquire(groups, acquire_amount, allow_partial_response: false, on_error: :log_and_pass)
      expiry_cache_key = "prefab.ratelimit.expiry:#{groups.join(".")}"
      expiry = @client.shared_cache.read(expiry_cache_key)
      if !expiry.nil? && Integer(expiry) > Time.now.utc.to_f * 1000
        @client.stats.increment("prefab.ratelimit.limitcheck.expirycache.hit", tags: [])
        return Prefab::LimitResponse.new(passed: false, amount: 0)
      end

      req = Prefab::LimitRequest.new(
        account_id: @client.account_id,
        acquire_amount: acquire_amount,
        groups: groups,
        allow_partial_response: allow_partial_response
      )

      result = Retry.it(method(:stub), :limit_check, req, @timeout)

      reset = result.limit_reset_at
      @client.shared_cache.write(expiry_cache_key, reset) unless reset < 1 # protobuf default int to 0

      @client.stats.increment("prefab.ratelimit.limitcheck", tags: ["policy_group:#{result.policy_group}", "pass:#{result.passed}"])

      result

    rescue => e
      handle_error(e, on_error, groups)
    end

    private

    def stub
      Prefab::RateLimitService::Stub.new(nil,
                                         nil,
                                         channel_override: @client.channel,
                                         timeout: @timeout,
                                         interceptors: [@client.interceptor])
    end

    def handle_error(e, on_error, groups)
      @client.stats.increment("prefab.ratelimit.error", tags: ["type:limit"])

      message = "ratelimit for #{groups} error: #{e.message}"
      case on_error
      when :log_and_pass
        @client.logger.warn(message)
        Prefab::LimitResponse.new(passed: true, amount: 0)
      when :log_and_hit
        @client.logger.warn(message)
        Prefab::LimitResponse.new(passed: false, amount: 0)
      when :throw
        raise e
      end
    end
  end
end

