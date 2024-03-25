# frozen_string_literal: true

module Prefab
  class Context
    BLANK_CONTEXT_NAME = ''

    class NamedContext
      attr_reader :name

      def initialize(name, hash)
        @name = name.to_s
        @hash = hash.transform_keys(&:to_s)
      end

      def to_h
        @hash
      end

      def key
        "#{@name}:#{@hash['key']}"
      end

      def to_proto
        PrefabProto::Context.new(
          type: name,
          values: @hash.transform_values do |value|
            ConfigValueWrapper.wrap(value)
          end
        )
      end
    end

    THREAD_KEY = :prefab_context
    attr_reader :contexts, :seen_at

    class << self
      def default_context=(context)
        @default_context = join(hash: context, parent: nil, id: :default)

        self.current.update_parent(@default_context)
      end

      def default_context
        @default_context ||= join(parent: nil, id: :default_context)
      end

      def current=(context)
        Thread.current[THREAD_KEY] = context
      end

      def current
        Thread.current[THREAD_KEY] ||= join(parent: default_context, id: :block)
      end

      def with_context(context)
        old_context = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = join(parent: default_context, hash: context, id: :block)
        yield
      ensure
        Thread.current[THREAD_KEY] = old_context
      end

      def with_merged_context(context)
        old_context = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = join(parent: current, hash: context, id: :merged)
        yield
      ensure
        Thread.current[THREAD_KEY] = old_context
      end

      def clear_current
        Thread.current[THREAD_KEY] = nil
      end

      def merge_with_current(new_context_properties = {})
        new(current.to_h.merge(new_context_properties.to_h))
      end
    end

    def self.join(hash: {}, parent: nil, id: :not_provided)
      context = new(hash)
      context.update_parent(parent)
      context.instance_variable_set(:@id, id)
      context
    end

    def initialize(hash = {})
      @contexts = {}
      @flattened = {}
      @seen_at = Time.now.utc.to_i
      warned = false

      if hash.is_a?(Hash)
        hash.map do |name, values|
          unless values.is_a?(Hash)
            warn "[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash."
            values = { name => values }
            name = BLANK_CONTEXT_NAME
          end

          @contexts[name.to_s] = NamedContext.new(name, values)
          values.each do |key, value|
            @flattened[name.to_s + '.' + key.to_s] = value
          end
        end
      else
        raise ArgumentError, 'must be a Hash'
      end
    end

    def update_parent(parent)
      @parent = parent
    end

    def blank?
      contexts.empty?
    end

    def set(name, hash)
      @contexts[name.to_s] = NamedContext.new(name, hash)
      hash.each do |key, value|
        @flattened[name.to_s + '.' + key.to_s] = value
      end
    end

    def get(property_key)
      if !property_key.include?(".")
        property_key = BLANK_CONTEXT_NAME + '.' + property_key
      end

      if @flattened.key?(property_key)
        @flattened[property_key]
      else
        @parent&.get(property_key)
      end
    end

    def to_h
      contexts.transform_values(&:to_h)
    end

    def clear
      @contexts = {}
    end

    def context(name)
      contexts[name.to_s] || NamedContext.new(name, {})
    end

    def merge_default(defaults)
      defaults.keys.each do |name|
        set(name, context(name).merge!(defaults[name]))
      end

      self
    end

    def to_proto(namespace)
      prefab_context = {
        'current-time' => ConfigValueWrapper.wrap(Prefab::TimeHelpers.now_in_ms)
      }

      prefab_context['namespace'] = ConfigValueWrapper.wrap(namespace) if namespace&.length&.positive?

      PrefabProto::ContextSet.new(
        contexts: contexts.map do |name, context|
          context.to_proto
        end.concat([PrefabProto::Context.new(type: 'prefab',
                                             values: prefab_context)])
      )
    end

    def slim_proto
      PrefabProto::ContextSet.new(
        contexts: contexts.map do |_, context|
          context.to_proto
        end
      )
    end

    def grouped_key
      contexts.map do |_, context|
        context.key
      end.sort.join('|')
    end

    include Comparable
    def <=>(other)
      if other.is_a?(Prefab::Context)
        to_h <=> other.to_h
      else
        super
      end
    end
  end
end
