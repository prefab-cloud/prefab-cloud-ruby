# prefab-cloud-ruby
Ruby Client for Prefab RateLimits, FeatureFlags, Config as a Service: https://www.prefab.cloud

```ruby
client = Prefab::Client.new
@feature_flags = client.feature_flag_client

# Create a flag that is on for 10% of traffic, the entire beta group and user:1
@feature_flags.upsert(Prefab::FeatureFlag.new(feature: "MyFeature", pct: 0.1, whitelisted: ["betas", "user:1"]))

# Use Flags By Themselves
puts @feature_flags.feature_is_on? "MyFeature"  # returns yes 10 pct of the time

# A single user should get the same result each time
puts @feature_flags.feature_is_on? "MyFeature", "user:1123"
```
See full documentation https://www.prefab.cloud/documentation/installation


## Supports

* [RateLimits](https://www.prefab.cloud/documentation/basic_rate_limits)
* Millions of individual limits sharing the same policies
* WebUI for tweaking limits & feature flags
* Infinite retention for [deduplication workflows](https://www.prefab.cloud/documentation/once_and_only_once)
* [FeatureFlags](https://www.prefab.cloud/documentation/feature_flags) as a Service

## Important note about Forking

Many ruby web servers fork. GRPC does not like to be forked. You should instantiate your prefab clients in the on_worker_boot or after_fork hook of your server. See some details on GRPC and forking: https://github.com/grpc/grpc/issues/7951#issuecomment-335998583

```ruby
#puma.rb
on_worker_boot do
  $prefab = Prefab::Client.new(shared_cache: Rails.cache,
                               logdev: $stdout,
                               log_formatter: proc {|severity, datetime, progname, msg|
                                 "#{severity.ljust(5)} #{datetime}: #{progname} #{msg}\n"
                               })
  Rails.logger = $prefab.log
end
```

## Contributing to prefab-cloud-ruby
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2018 Jeff Dwyer. See LICENSE.txt for
further details.
