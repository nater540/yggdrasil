module Yggdrasil

  # Simple lookup system for mapping database field types to GraphQL types.
  #
  # @since 1.0.0
  # @author Nate Strandberg
  #
  module TypeRegistry
    TypeStruct = Struct.new(:output, :input)

    class << self

      # Adds a new database type.
      #
      # @param [Symbol] type The database type to add.
      # @param [GraphQL::ScalarType, Symbol, String, Proc] output_type
      # @param [GraphQL::ScalarType, Symbol, String, Proc] input_type
      def add(type:, output_type:, input_type: output_type)

        if !input_type.is_a?(GraphQL::BaseType) || !output_type.is_a?(GraphQL::BaseType)
          output_type = output_type.call if output_type.is_a?(Proc)
          input_type  = input_type.call  if input_type.is_a?(Proc)

          output_type = output_type.constantize if output_type.is_a?(String)
          input_type  = input_type.constantize if input_type.is_a?(String)
        end

        types[type] = TypeStruct.new(output_type, input_type)
      end

      # Attempts to get a GraphQL type using a given database type.
      #
      # @param [Symbol] type The database type to get.
      # @param [Boolean] raise_on_error Whether or not an exception should be raised if the type does not exist.
      # @return [Struct, Nil]
      #
      # @raise [ArgumentError] If the type does not exist and the raise_on_error argument is true.
      def get(type, raise_on_error: true)
        found_type = types[type]

        raise ArgumentError, "`#{type}` does not exist inside the Yggdrasil type registry." if raise_on_error && found_type.nil?
        found_type
      end

      # @return [Hash]
      def types
        @types ||= {}.with_indifferent_access
      end
    end
  end

  # Add a bunch of common well-known types to the registry
  TypeRegistry.add(type: :boolean, output_type: GraphQL::BOOLEAN_TYPE)
  TypeRegistry.add(type: :integer, output_type: GraphQL::INT_TYPE)
  TypeRegistry.add(type: :decimal, output_type: GraphQL::FLOAT_TYPE)
  TypeRegistry.add(type: :string,  output_type: GraphQL::STRING_TYPE)
  TypeRegistry.add(type: :binary,  output_type: GraphQL::STRING_TYPE)
  TypeRegistry.add(type: :float,   output_type: GraphQL::FLOAT_TYPE)
  TypeRegistry.add(type: :text,    output_type: GraphQL::STRING_TYPE)
  TypeRegistry.add(type: :uuid,    output_type: GraphQL::STRING_TYPE)
  TypeRegistry.add(type: :enum,    output_type: GraphQL::STRING_TYPE)
end
