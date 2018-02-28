module Prefab
  class RateLimitClient

    def initialize(base_client, timeout)
      @timeout = timeout
      @base_client = base_client
    end

    def pass?(group)
      result = acquire([group], 1)
      return result.passed
    end

    def acquire(groups, acquire_amount, allow_partial_response: false, on_error: :log_and_pass)
      expiry_cache_key = "prefab.ratelimit.expiry:#{groups.join(".")}"
      expiry = @base_client.shared_cache.read(expiry_cache_key)
      if !expiry.nil? && Integer(expiry) > Time.now.utc.to_f * 1000
        @base_client.stats.increment("prefab.ratelimit.limitcheck.expirycache.hit", tags: [])
        return Prefab::LimitResponse.new(passed: false, amount: 0)
      end

      req = Prefab::LimitRequest.new(
        account_id: @base_client.account_id,
        acquire_amount: acquire_amount,
        groups: groups,
        allow_partial_response: allow_partial_response
      )

      result = @base_client.request Prefab::RateLimitService, :limit_check, req_options: {timeout: @timeout}, params: req

      reset = result.limit_reset_at
      @base_client.shared_cache.write(expiry_cache_key, reset) unless reset < 1 # protobuf default int to 0

      @base_client.stats.increment("prefab.ratelimit.limitcheck", tags: ["policy_group:#{result.policy_group}", "pass:#{result.passed}"])

      result

    rescue => e
      handle_error(e, on_error, groups)
    end

    def upsert(group, policy_name, limit, burst)
      limit_defintion = Prefab::LimitDefinition.new(
        account_id: @base_client.account_id,
        group: group,
        policy_name: policy_name,
        limit: limit,
        burst: burst
      )
      @base_client.request Prefab::RateLimitService, :upsert_limit_definition, params: limit_defintion
    end

    private

    def handle_error(e, on_error, groups)
      @base_client.stats.increment("prefab.ratelimit.error", tags: ["type:limit"])

      message = "ratelimit for #{groups} error: #{e.message}"
      case on_error
      when :log_and_pass
        @base_client.logger.warn(message)
        Prefab::LimitResponse.new(passed: true, amount: 0)
      when :log_and_hit
        @base_client.logger.warn(message)
        Prefab::LimitResponse.new(passed: false, amount: 0)
      when :throw
        raise e
      end
    end
  end
end

