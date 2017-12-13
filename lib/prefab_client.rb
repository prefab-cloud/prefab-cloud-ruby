
require 'rubygems'
require 'bundler'
Bundler.require(:default, :development)
require "concurrent/atomics"
require 'concurrent'
require_relative 'prefab/config_loader'
require_relative 'prefab/config_resolver'
require_relative 'prefab/client'
require_relative 'prefab/prefab_pb'
require_relative 'prefab/prefab_services_pb'
require_relative 'prefab/ratelimit_pb'
require_relative 'prefab/auth_interceptor'


client = Prefab::Client.new(api_key: ENV["RATELIMIT_API_KEY"], local: true)
client.run
