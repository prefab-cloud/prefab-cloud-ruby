# frozen_string_literal: true

module Prefab
  class ConfigResolver
    attr_accessor :project_env_id # this will be set by the config_client when it gets an API response
    attr_reader :local_store

    attr_accessor :default_context

    def initialize(base_client, config_loader)
      @lock = Concurrent::ReadWriteLock.new
      @local_store = {}
      @config_loader = config_loader
      @project_env_id = 0 # we don't know this yet, it is set from the API results
      @base_client = base_client
      @on_update = nil
      @default_context = {}
      make_local
    end

    def to_s
      presenter.to_s
    end

    def presenter
      Prefab::ResolvedConfigPresenter.new(self, @lock, @local_store)
    end

    def raw(key)
      @local_store.dig(key, :config)
    end

    def get(key, properties = NO_DEFAULT_PROVIDED)
      @lock.with_read_lock do
        raw_config = raw(key)

        return nil unless raw_config

        evaluate(raw_config, properties)
      end
    end

    def evaluate(config, properties = NO_DEFAULT_PROVIDED)
      Prefab::CriteriaEvaluator.new(config,
                                    project_env_id: @project_env_id,
                                    resolver: self,
                                    base_client: @base_client).evaluate(make_context(properties))
    end

    def update
      make_local

      @on_update ? @on_update.call : nil
    end

    def on_update(&block)
      @on_update = block
    end

    def make_context(properties)
      if properties == NO_DEFAULT_PROVIDED || properties.nil?
        Context.current
      elsif properties.is_a?(Context)
        properties
      else
        Context.merge_with_current(properties)
      end.merge_default(default_context || {})
    end

    private

    def make_local
      @lock.with_write_lock do
        @local_store = @config_loader.calc_config
      end
    end
  end
end
