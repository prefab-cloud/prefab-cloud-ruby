# frozen_string_literal: true
module Prefab
  class Options
    attr_reader :api_key
    attr_reader :logdev
    attr_reader :log_formatter
    attr_reader :stats
    attr_reader :shared_cache
    attr_reader :namespace
    attr_reader :prefab_api_url
    attr_reader :prefab_grpc_url
    attr_reader :on_no_default
    attr_reader :initialization_timeout_sec
    attr_reader :on_init_failure
    attr_reader :prefab_config_override_dir
    attr_reader :prefab_config_classpath_dir
    attr_reader :prefab_envs

    DEFAULT_LOG_FORMATTER = proc { |severity, datetime, progname, msg|
      "#{severity.ljust(5)} #{datetime}: #{progname} #{msg}\n"
    }

    module ON_INITIALIZATION_FAILURE
      RAISE = 1
      RETURN = 2
    end
    module ON_NO_DEFAULT
      RAISE = 1
      RETURN_NIL = 2
    end
    module DATASOURCES
      ALL = 1
      LOCAL_ONLY = 2
    end

    def initialize(
      api_key: ENV['PREFAB_API_KEY'],
      logdev: $stdout,
      stats: NoopStats.new, # receives increment("prefab.limitcheck", {:tags=>["policy_group:page_view", "pass:true"]})
      shared_cache: NoopCache.new, # Something that quacks like Rails.cache ideally memcached
      namespace: "",
      log_formatter: DEFAULT_LOG_FORMATTER,
      prefab_api_url: ENV["PREFAB_API_URL"] || 'https://api.prefab.cloud',
      prefab_grpc_url: ENV["PREFAB_GRPC_URL"] || 'grpc.prefab.cloud:443',
      on_no_default: ON_NO_DEFAULT::RAISE, # options :raise, :warn_and_return_nil,
      initialization_timeout_sec: 10, # how long to wait before on_init_failure
      on_init_failure: ON_INITIALIZATION_FAILURE::RAISE, #options :unlock_and_continue, :lock_and_keep_trying, :raise
      # new_config_callback: nil, #callback method
      # live_override_url: nil,
      prefab_datasources: ENV['PREFAB_DATASOURCES'] == "LOCAL_ONLY" ? DATASOURCES::LOCAL_ONLY : DATASOURCES::ALL,
      prefab_config_override_dir: Dir.home,
      prefab_config_classpath_dir: ".",
      prefab_envs:  ENV['PREFAB_ENVS'].nil? ? [] : ENV['PREFAB_ENVS'].split(",")
    )
      # debugger
      @api_key = api_key
      @logdev = logdev
      @stats = stats
      @shared_cache = shared_cache
      @namespace = namespace
      @log_formatter = log_formatter
      @prefab_api_url = prefab_api_url
      @prefab_grpc_url = prefab_grpc_url
      @on_no_default = on_no_default
      @initialization_timeout_sec = initialization_timeout_sec
      @on_init_failure = on_init_failure
      @prefab_datasources = prefab_datasources
      @prefab_config_classpath_dir = prefab_config_classpath_dir
      @prefab_config_override_dir = prefab_config_override_dir
      @prefab_envs = Array(prefab_envs)
    end

    def local_only?
      @prefab_datasources == DATASOURCES::LOCAL_ONLY
    end

    # https://api.prefab.cloud -> https://api-prefab-cloud.global.ssl.fastly.net
    def url_for_api_cdn
      ENV['PREFAB_CDN_URL'] || "#{@prefab_api_url.gsub(/\./, "-")}.global.ssl.fastly.net"
    end
  end
end
