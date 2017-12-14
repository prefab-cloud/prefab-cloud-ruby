
require 'rubygems'
require 'bundler'
Bundler.require(:default, :development)
require "concurrent/atomics"
require 'concurrent'
require_relative 'prefab/prefab_pb'
require_relative 'prefab/prefab_services_pb'
require_relative 'prefab/ratelimit_pb'
require_relative 'prefab/config_loader'
require_relative 'prefab/config_resolver'
require_relative 'prefab/client'
require_relative 'prefab/ratelimit_client'
require_relative 'prefab/config_client'
require_relative 'prefab/auth_interceptor'
require_relative 'prefab/noop_cache'
require_relative 'prefab/noop_stats'


client = Prefab::Client.new(api_key: ENV["RATELIMIT_API_KEY"], local: false)

start = Time.now
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"
puts "pass? #{client.ratelimit_client.pass? "hubtest.secondly"}"

puts "took #{Time.now - start}"

# @@prefab = Prefab::Client.new(api_key: ENV["RATELIMIT_API_KEY"], local: true)
# @@prefab.rate_limits.check()
