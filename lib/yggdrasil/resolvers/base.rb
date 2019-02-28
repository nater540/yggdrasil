module Yggdrasil
  module Resolvers
    module Base

      def initialize(**options)
        # noinspection RubyArgCount
        @search = Search.new(nil, nil, nil)
      end

      def results
        @results ||= @search.query(self)
      end

      def results?
        results.any?
      end

      def count
        @count ||= @search.count(self)
      end

      module ClassMethods
        attr_reader :config

        def inherited(base)
          base.instance_variable_set '@config', {}
        end

        # @return [GraphQL::Define::TypeDefiner]
        def types
          GraphQL::Define::TypeDefiner.instance
        end

        def call(obj, args, ctx)
          'puff the magic dragon'
        end

        # Create a new filter option.
        #
        # @param [String, Symbol] name The filter name.
        # @param [Hash] options
        def filter(name, **options)
          define_method(name) { options }
        end

        def results(*args)
          new(*args).results
        end
      end

      # @param [Base] base
      def self.included(base)
        base.extend ClassMethods
        base.instance_eval do
          @config = {
            scope: nil,
            params: [],
            actions: []
          }
        end
      end
    end
  end
end
