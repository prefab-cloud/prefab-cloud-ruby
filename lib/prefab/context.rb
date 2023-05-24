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
    end

    class Registry
      class << self
        def get(name)
          @contexts ||= Concurrent::Map.new
          @contexts[name]
        end

        def set(name, context)
          @contexts ||= Concurrent::Map.new
          @contexts[name] = context
        end

        def with(name)
          Prefab::Context.with_context(get(name)) { yield }
        end

        def discard(name)
          @contexts ||= Concurrent::Map.new
          @contexts.delete(name)
        end
      end
    end

    THREAD_KEY = :prefab_context
    attr_reader :contexts

    class << self
      def current=(context)
        Thread.current[THREAD_KEY] = context
      end

      def current
        Thread.current[THREAD_KEY] ||= new
      end

      def with_context(context, register_as: nil, &block)
        old_context = current
        new_context = new(context)

        Registry.set(register_as, new_context) if register_as

        self.current = new_context
        yield
      ensure
        self.current = old_context
      end

      def clear_current
        self.current = nil
      end

      def merge_with_current(new_context_properties = {})
        new(current.to_h.merge(new_context_properties))
      end

      def thread_id
        Thread.current.__id__
      end
    end

    def initialize(context = {})
      @contexts = {}

      if context.is_a?(Prefab::Context)
        @contexts = context.contexts
      elsif context.is_a?(NamedContext)
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

    def set(name, hash)
      @contexts[name.to_s] = NamedContext.new(name, hash)
    end

    def get(property_key)
      name, key = property_key.split('.', 2)

      if key.nil?
        name = BLANK_CONTEXT_NAME
        key = property_key
      end

      contexts[name] && contexts[name].get(key)
    end

    def to_h
      contexts.map { |name, context| [name, context.to_h] }.to_h
    end

    def clear
      @contexts = {}
    end

    def context(name)
      contexts[name.to_s] || NamedContext.new(name, {})
    end

    def to_s
      "#<#{self.class.name}:#{object_id} contexts=#{contexts.inspect}>"
    end
  end
end
