# frozen_string_literal: true

module Prefab
  class Context
    BLANK_CONTEXT_NAME = ''

    class NamedContext
      attr_reader :name

      def initialize(name, hash)
        @hash = {}
        @name = name.to_s

        merge!(hash)
      end

      def get(parts)
        @hash[parts]
      end

      def merge!(other)
        @hash = @hash.merge(other.transform_keys(&:to_s))
      end

      def to_h
        @hash
      end

      def key
        "#{@name}:#{get('key')}"
      end

      def to_proto
        PrefabProto::Context.new(
          type: name,
          values: to_h.transform_values do |value|
            ConfigValueWrapper.wrap(value)
          end
        )
      end
    end

    THREAD_KEY = :prefab_context
    attr_reader :contexts, :seen_at

    class << self
      def current=(context)
        Thread.current[THREAD_KEY] = context
      end

      def current
        Thread.current[THREAD_KEY] ||= new
      end

      def with_context(context)
        old_context = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = new(context)
        yield
      ensure
        Thread.current[THREAD_KEY] = old_context
      end

      def clear_current
        Thread.current[THREAD_KEY] = nil
      end

      def merge_with_current(new_context_properties = {})
        new(current.to_h.merge(new_context_properties))
      end
    end

    def initialize(context = {})
      @contexts = {}
      @seen_at = Time.now.utc.to_i

      if context.is_a?(NamedContext)
        @contexts[context.name] = context
      elsif context.is_a?(Hash)
        context.map do |name, values|
          if values.is_a?(Hash)
            @contexts[name.to_s] = NamedContext.new(name, values)
          else
            warn '[DEPRECATION] Prefab contexts should be a hash with a key of the context name and a value of a hash.'

            @contexts[BLANK_CONTEXT_NAME] ||= NamedContext.new(BLANK_CONTEXT_NAME, {})
            @contexts[BLANK_CONTEXT_NAME].merge!({ name => values })
          end
        end
      else
        raise ArgumentError, 'must be a Hash or a NamedContext'
      end
    end

    def blank?
      contexts.empty?
    end

    def set(name, hash)
      @contexts[name.to_s] = NamedContext.new(name, hash)
    end

    def get(property_key)
      name, key = property_key.split('.', 2)

      if key.nil?
        name = BLANK_CONTEXT_NAME
        key = property_key
      end

      contexts[name]&.get(key)
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
