# frozen_string_literal: true

module Prefab
  LOG = Prefab::InternalLogger.new(self)
  @@lock = Concurrent::ReadWriteLock.new
  @config_has_loaded = false

  def self.init(options = Prefab::Options.new)
    unless @singleton.nil?
      LOG.warn 'Prefab already initialized.'
      return @singleton
    end

    @@lock.with_write_lock {
      @singleton = Prefab::Client.new(options)
    }
  end

  def self.fork
    ensure_initialized
    @@lock.with_write_lock {
      @singleton = @singleton.fork
    }
  end

  def self.set_rails_loggers
    ensure_initialized
    @singleton.set_rails_loggers
  end

  def self.get(key, default = NO_DEFAULT_PROVIDED, jit_context = NO_DEFAULT_PROVIDED)
    ensure_initialized key
    @singleton.get(key, default, jit_context)
  end

  def self.enabled?(feature_name, jit_context = NO_DEFAULT_PROVIDED)
    ensure_initialized feature_name
    @singleton.enabled?(feature_name, jit_context)
  end

  def self.with_context(properties, &block)
    ensure_initialized
    @singleton.with_context(properties, &block)
  end

  def self.instance
    ensure_initialized
    @singleton
  end

  def self.log_filter
    InternalLogger.using_prefab_log_filter!
    return Proc.new do |log|
      if defined?(@singleton) && !@singleton.nil? && @singleton.config_client.initialized?
        @singleton.log.semantic_filter(log)
      else
        bootstrap_log_level(log)
      end
    end
  end

  def self.finish_init!
    @config_has_loaded = true
  end

  def self.bootstrap_log_level(log)
    level = ENV['PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL'] ? ENV['PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL'].downcase.to_sym : :warn
    SemanticLogger::Levels.index(level) <= SemanticLogger::Levels.index(log.level)
  end

  def self.defined?(key)
    ensure_initialized key
    @singleton.defined?(key)
  end

  def self.is_ff?(key)
    ensure_initialized key
    @singleton.is_ff?(key)
  end

  def self.bootstrap_javascript(context)
    ensure_initialized
    Prefab::JavaScriptStub.new(@singleton).bootstrap(context)
  end

  def self.generate_javascript_stub(context)
    ensure_initialized
    Prefab::JavaScriptStub.new(@singleton).generate_stub(context)
  end

  private

  def self.ensure_initialized(key = nil)
    if not defined? @singleton or @singleton.nil?
      raise Prefab::Errors::UninitializedError.new(key)
    end
  end
end
