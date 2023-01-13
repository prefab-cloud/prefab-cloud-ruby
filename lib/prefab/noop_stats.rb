# frozen_string_literal: true

module Prefab
  class NoopStats
    # receives increment("prefab.ratelimit.limitcheck", {:tags=>["policy_group:page_view", "pass:true"]})
    def increment(name, opts = {}); end
  end
end
