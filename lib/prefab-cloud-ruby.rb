# frozen_string_literal: true

module Prefab
  NO_DEFAULT_PROVIDED = :no_default_provided
end

require 'concurrent/atomics'
require 'concurrent'
require 'faraday'
require 'openssl'
require 'openssl'
require 'ld-eventsource'
require 'prefab_pb'
require 'prefab/error'
require 'prefab/exponential_backoff'
require 'prefab/errors/initialization_timeout_error'
require 'prefab/errors/invalid_api_key_error'
require 'prefab/errors/missing_default_error'
require 'prefab/options'
require 'prefab/internal_logger'
require 'prefab/log_path_aggregator'
require 'prefab/context_shape_aggregator'
require 'prefab/sse_logger'
require 'prefab/weighted_value_resolver'
require 'prefab/config_value_unwrapper'
require 'prefab/criteria_evaluator'
require 'prefab/config_loader'
require 'prefab/context_shape'
require 'prefab/local_config_parser'
require 'prefab/yaml_config_parser'
require 'prefab/resolved_config_presenter'
require 'prefab/config_resolver'
require 'prefab/http_connection'
require 'prefab/context'
require 'prefab/client'
require 'prefab/config_client'
require 'prefab/feature_flag_client'
require 'prefab/logger_client'
require 'prefab/noop_cache'
require 'prefab/noop_stats'
require 'prefab/murmer3'
