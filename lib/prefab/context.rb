# frozen_string_literal: true

module Prefab
  class Context
    class NamedContext
      attr_reader :name

      def initialize(name, hash)
        @hash = {}
        @name = name.to_s

        merge(hash)
      end

      def get(parts)
        @hash[parts]
      end

      def merge(other)
        @hash = @hash.merge(other.transform_keys(&:to_s))
      end

      def to_h
        @hash
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

      if context.is_a?(NamedContext)
        @contexts[context.name] = context
      elsif context.is_a?(Hash)
        context.map do |name, hash|
          unless hash.is_a?(Hash)
            raise ArgumentError,
                  "Contexts should be a hash with a key of the context name and a value of a hash. You provided a #{hash.class} #{hash.inspect}"
          end

          @contexts[name.to_s] = NamedContext.new(name, hash)
        end
      else
        raise ArgumentError, 'must be a Hash or a NamedContext'
      end
    end

    def merge!(name, hash)
      @contexts[name.to_s] = context(name).merge(hash)
    end

    def set(name, hash)
      @contexts[name.to_s] = NamedContext.new(name, hash)
    end

    def []=(name, hash)
      set(name, hash)
    end

    def get(property_key)
      name, key = property_key.split('.', 2)

      if key.nil?
        name = ''
        key = property_key
      end

      contexts[name] && contexts[name].get(key)
    end

    def [](property_key)
      get(property_key)
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
  end
end
