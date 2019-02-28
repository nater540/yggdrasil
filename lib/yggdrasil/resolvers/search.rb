module Yggdrasil
  module Resolvers
    class Search
      attr_reader :scope, :params, :actions

      # Constructor
      #
      # @param [Object] scope
      # @param [Array] params
      # @param [Array] actions
      def initialize(scope, params, actions)
        @actions = actions
        @params  = params
        @scope   = scope
      end

      # @param [String, Symbol] name
      def param(name)
        @params[name]
      end

      # @param [Hash] context
      def query(context)
        @params.inject(@scope) do |scope, (name, value)|
          new_scope = context.instance_exec scope, value, &@actions[name]
          new_scope || scope
        end
      end

      # @param [Hash] context
      def count(context)
        query(context).count
      end
    end
  end
end
