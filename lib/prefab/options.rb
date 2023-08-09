# frozen_string_literal: true

module Prefab
  # This class contains all the options that can be passed to the Prefab client.
  class Options
    attr_reader :api_key
    attr_reader :logdev
    attr_reader :log_prefix
    attr_reader :log_formatter
    attr_reader :namespace
    attr_reader :prefab_api_url
    attr_reader :on_no_default
    attr_reader :initialization_timeout_sec
    attr_reader :on_init_failure
    attr_reader :prefab_config_override_dir
    attr_reader :prefab_config_classpath_dir
    attr_reader :prefab_envs
    attr_reader :collect_sync_interval

    DEFAULT_LOG_FORMATTER = proc { |severity, datetime, progname, msg|
      "#{severity.ljust(5)} #{datetime}:#{' ' if progname}#{progname} #{msg}\n"
    }
    JSON_LOG_FORMATTER = proc { |severity, datetime, progname, msg, path|
      {
        type: severity,
        time: datetime,
        progname: progname,
        message: msg,
        path: path
      }.compact.to_json << "\n"
    }

    module ON_INITIALIZATION_FAILURE
      RAISE = :raise
      RETURN = :return
    end

    module ON_NO_DEFAULT
      RAISE = :raise
      RETURN_NIL = :return_nil
    end

    module DATASOURCES
      ALL = :all
      LOCAL_ONLY = :local_only
    end

    DEFAULT_MAX_PATHS = 1_000
    DEFAULT_MAX_KEYS = 100_000
    DEFAULT_MAX_EXAMPLE_CONTEXTS = 100_000
    DEFAULT_MAX_EVAL_SUMMARIES = 100_000

    private def init(
      api_key: ENV['PREFAB_API_KEY'],
      logdev: $stdout,
      namespace: '',
      log_formatter: DEFAULT_LOG_FORMATTER,
      log_prefix: nil,
      prefab_api_url: ENV['PREFAB_API_URL'] || 'https://api.prefab.cloud',
      on_no_default: ON_NO_DEFAULT::RAISE, # options :raise, :warn_and_return_nil,
      initialization_timeout_sec: 10, # how long to wait before on_init_failure
      on_init_failure: ON_INITIALIZATION_FAILURE::RAISE,
      prefab_datasources: ENV['PREFAB_DATASOURCES'] == 'LOCAL_ONLY' ? DATASOURCES::LOCAL_ONLY : DATASOURCES::ALL,
      prefab_config_override_dir: Dir.home,
      prefab_config_classpath_dir: '.',
      prefab_envs: ENV['PREFAB_ENVS'].nil? ? [] : ENV['PREFAB_ENVS'].split(','),
      collect_logger_counts: true,
      collect_max_paths: DEFAULT_MAX_PATHS,
      collect_sync_interval: nil,
      collect_keys: false,
      collect_max_keys: DEFAULT_MAX_KEYS,
      context_upload_mode: :periodic_example, # :periodic_example, :shape_only, :none
      context_max_size: DEFAULT_MAX_EVAL_SUMMARIES,
      collect_evaluation_summaries: false,
      collect_max_evaluation_summaries: DEFAULT_MAX_EVAL_SUMMARIES,
      allow_telemetry_in_local_mode: false
    )
      @api_key = api_key
      @logdev = logdev
      @namespace = namespace
      @log_formatter = log_formatter
      @log_prefix = log_prefix
      @prefab_api_url = remove_trailing_slash(prefab_api_url)
      @on_no_default = on_no_default
      @initialization_timeout_sec = initialization_timeout_sec
      @on_init_failure = on_init_failure
      @prefab_datasources = prefab_datasources
      @prefab_config_classpath_dir = prefab_config_classpath_dir
      @prefab_config_override_dir = prefab_config_override_dir
      @prefab_envs = Array(prefab_envs)
      @collect_logger_counts = collect_logger_counts
      @collect_max_paths = collect_max_paths
      @collect_sync_interval = collect_sync_interval
      @collect_keys = collect_keys
      @collect_max_keys = collect_max_keys
      @collect_evaluation_summaries = collect_evaluation_summaries
      @collect_max_evaluation_summaries = collect_max_evaluation_summaries
      @allow_telemetry_in_local_mode = allow_telemetry_in_local_mode

      # defaults that may be overridden by context_upload_mode
      @collect_shapes = false
      @collect_max_shapes = 0
      @collect_example_contexts = false
      @collect_max_example_contexts = 0

      case context_upload_mode
      when :none
        # do nothing
      when :periodic_example
        @collect_example_contexts = true
        @collect_max_example_contexts = context_max_size
      when :shape_only
        @collect_shapes = true
        @collect_max_shapes = context_max_size
      else
        raise "Unknown context_upload_mode #{context_upload_mode}. Please provide :periodic_example, :shape_only, or :none."
      end
    end

    def initialize(options = {})
      init(**options)
    end

    def local_only?
      @prefab_datasources == DATASOURCES::LOCAL_ONLY
    end

    def collect_max_paths
      return 0 unless telemetry_allowed?(@collect_logger_counts)

      @collect_max_paths
    end

    def collect_max_shapes
      return 0 unless telemetry_allowed?(@collect_shapes)

      @collect_max_shapes
    end

    def collect_max_keys
      return 0 unless telemetry_allowed?(@collect_keys)

      @collect_max_keys
    end

    def collect_max_example_contexts
      return 0 unless telemetry_allowed?(@collect_example_contexts)

      @collect_max_example_contexts
    end

    def collect_max_evaluation_summaries
      return 0 unless telemetry_allowed?(@collect_evaluation_summaries)

      @collect_max_evaluation_summaries
    end

    # https://api.prefab.cloud -> https://api-prefab-cloud.global.ssl.fastly.net
    def url_for_api_cdn
      ENV['PREFAB_CDN_URL'] || "#{@prefab_api_url.gsub(/\./, '-')}.global.ssl.fastly.net"
    end

    private

    def telemetry_allowed?(option)
      option && (!local_only? || @allow_telemetry_in_local_mode)
    end

    def remove_trailing_slash(url)
      url.end_with?('/') ? url[0..-2] : url
    end
  end
end
