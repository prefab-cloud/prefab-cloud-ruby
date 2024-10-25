# frozen_string_literal: true

module Prefab
  # This class contains all the options that can be passed to the Prefab client.
  class Options
    attr_reader :api_key
    attr_reader :namespace
    attr_reader :sources
    attr_reader :sse_sources
    attr_reader :telemetry_destination
    attr_reader :config_sources
    attr_reader :on_no_default
    attr_reader :initialization_timeout_sec
    attr_reader :on_init_failure
    attr_reader :prefab_config_override_dir
    attr_reader :prefab_config_classpath_dir
    attr_reader :prefab_envs
    attr_reader :collect_sync_interval
    attr_reader :use_local_cache
    attr_reader :datafile
    attr_reader :global_context
    attr_accessor :is_fork
    attr_reader :symbolize_json_names

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

    DEFAULT_SOURCES = [
      "https://belt.prefab.cloud",
      "https://suspenders.prefab.cloud",
    ].freeze

    private def init(
      sources: nil,
      api_key: ENV['PREFAB_API_KEY'],
      namespace: '',
      prefab_api_url: nil,
      on_no_default: ON_NO_DEFAULT::RAISE, # options :raise, :warn_and_return_nil,
      initialization_timeout_sec: 10, # how long to wait before on_init_failure
      on_init_failure: ON_INITIALIZATION_FAILURE::RAISE,
      prefab_datasources: ENV['PREFAB_DATASOURCES'] == 'LOCAL_ONLY' ? DATASOURCES::LOCAL_ONLY : DATASOURCES::ALL,
      prefab_config_override_dir: Dir.home,
      prefab_config_classpath_dir: '.', # where to load local overrides
      prefab_envs: ENV['PREFAB_ENVS'].nil? ? [] : ENV['PREFAB_ENVS'].split(','),
      collect_logger_counts: true,
      collect_max_paths: DEFAULT_MAX_PATHS,
      collect_sync_interval: nil,
      context_upload_mode: :periodic_example, # :periodic_example, :shape_only, :none
      context_max_size: DEFAULT_MAX_EVAL_SUMMARIES,
      collect_evaluation_summaries: true,
      collect_max_evaluation_summaries: DEFAULT_MAX_EVAL_SUMMARIES,
      allow_telemetry_in_local_mode: false,
      datafile: ENV['PREFAB_DATAFILE'],
      x_datafile: nil, # DEPRECATED in favor of `datafile`
      x_use_local_cache: false,
      symbolize_json_names: false,
      global_context: {}
    )
      @api_key = api_key
      @namespace = namespace
      @on_no_default = on_no_default
      @initialization_timeout_sec = initialization_timeout_sec
      @on_init_failure = on_init_failure
      @prefab_datasources = prefab_datasources

      @datafile = datafile || x_datafile

      if !x_datafile.nil?
        warn '[DEPRECATION] x_datafile is deprecated. Please provide `datafile` instead'
      end

      @prefab_config_classpath_dir = prefab_config_classpath_dir
      @prefab_config_override_dir = prefab_config_override_dir
      @prefab_envs = Array(prefab_envs)
      @collect_logger_counts = collect_logger_counts
      @collect_max_paths = collect_max_paths
      @collect_sync_interval = collect_sync_interval
      @collect_evaluation_summaries = collect_evaluation_summaries
      @collect_max_evaluation_summaries = collect_max_evaluation_summaries
      @allow_telemetry_in_local_mode = allow_telemetry_in_local_mode
      @use_local_cache = x_use_local_cache
      @is_fork = false
      @global_context = global_context
      @symbolize_json_names = symbolize_json_names

      # defaults that may be overridden by context_upload_mode
      @collect_shapes = false
      @collect_max_shapes = 0
      @collect_example_contexts = false
      @collect_max_example_contexts = 0

      if ENV['PREFAB_API_URL_OVERRIDE'] && ENV['PREFAB_API_URL_OVERRIDE'].length > 0
        sources = ENV['PREFAB_API_URL_OVERRIDE']
      end

      @sources = Array(sources || DEFAULT_SOURCES).map {|source| remove_trailing_slash(source) }

      @sse_sources = @sources
      @config_sources = @sources

      @telemetry_destination = @sources.select do |source|
        source.start_with?('https://') && (source.include?("belt") || source.include?("suspenders"))
      end.map do |source|
        source.sub(/(belt|suspenders)\./, 'telemetry.')
      end[0]

      if prefab_api_url
        warn '[DEPRECATION] prefab_api_url is deprecated. Please provide `sources` if you need to override the default sources'
      end

      case context_upload_mode
      when :none
        # do nothing
      when :periodic_example
        @collect_example_contexts = true
        @collect_max_example_contexts = context_max_size
        @collect_shapes = true
        @collect_max_shapes = context_max_size
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

    def datafile?
      !@datafile.nil?
    end

    def collect_max_paths
      return 0 unless telemetry_allowed?(@collect_logger_counts)

      @collect_max_paths
    end

    def collect_max_shapes
      return 0 unless telemetry_allowed?(@collect_shapes)

      @collect_max_shapes
    end

    def collect_max_example_contexts
      return 0 unless telemetry_allowed?(@collect_example_contexts)

      @collect_max_example_contexts
    end

    def collect_max_evaluation_summaries
      return 0 unless telemetry_allowed?(@collect_evaluation_summaries)

      @collect_max_evaluation_summaries
    end

    def api_key_id
      @api_key&.split("-")&.first
    end

    def for_fork
      clone = self.clone
      clone.is_fork = true
      clone
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
