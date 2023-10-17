# frozen_string_literal: true

module Prefab
  @@lock = Concurrent::ReadWriteLock.new

  def self.init(options = Prefab::Options.new)
    unless @singleton.nil?
      Prefab::LoggerClient.instance.warn 'Prefab already initialized.'
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

  def self.get(key, properties = NO_DEFAULT_PROVIDED)
    ensure_initialized
    @singleton&.get(key, properties)
  end

  def self.enabled?(feature_name, jit_context = NO_DEFAULT_PROVIDED)
    ensure_initialized
    @singleton&.enabled?(feature_name, jit_context)
  end

  def self.with_context(properties, &block)
    ensure_initialized
    @singleton.with_context(properties, &block)
  end

  def self.instance
    ensure_initialized
    @singleton
  end

  private

  def self.ensure_initialized
    if not defined? @singleton or @singleton.nil?
      raise "Use Prefab.initialize before calling Prefab.get"
    end
  end
end
