module Prefab
  class RateLimitClient
    def initialize(ratelimit_service, client)
      @ratelimit_service = ratelimit_service
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
        return It::Ratelim::Data::LimitResponse.new(passed: false, amount: 0)
      end

      req = It::Ratelim::Data::LimitRequest.new(
        account_id: @client.account_id,
        acquire_amount: acquire_amount,
        groups: groups,
        allow_partial_response: allow_partial_response
      )

      result = @ratelimit_service.limit_check(req)

      reset = result.limit_reset_at
      @client.shared_cache.write(expiry_cache_key, reset) unless reset < 1

      @client.stats.increment("prefab.ratelimit.limitcheck", tags: ["policy_group:#{result.policy_group}", "pass:#{result.passed}"])

      result

    rescue => e
      handle_error(e, on_error)
    end

    private

    def handle_error(e, on_error)
      @client.stats.increment("prefab.ratelimit.error", tags: ["type:limit"])
      case on_error
      when :log_and_pass
        @client.logger.warn(e)
        It::Ratelim::Data::LimitResponse.new(passed: true, amount: 0)
      when :log_and_hit
        @client.logger.warn(e)
        It::Ratelim::Data::LimitResponse.new(passed: false, amount: 0)
      when :throw
        raise e
      end
    end
  end
end

