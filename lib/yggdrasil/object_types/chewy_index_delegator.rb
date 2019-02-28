gem 'chewy', '>= 0.10.1'
require 'chewy'

module Yggdrasil

  # Decorator class for ElasticSearch Chewy indicies.
  #
  # @author Nate Strandberg
  # @since 1.0.0
  #
  class ChewyIndexDelegator < SimpleDelegator
    attr_reader :index_name

    # Constructor
    def initialize(obj, index_name, options = {})
      super(obj)

      # Sanity check
      raise ArgumentError, "#{self.class} cannot be used for `#{obj.class}` objects." unless obj.is_a?(Chewy::Index)

      # Get the first type name from the index unless one was provided for us
      @index_name = index_name || obj.type_names.first

      # Normalize the index mapping so we can quickly lookup fields & nested associations
      @fields, @nested = normalize_index(obj.type(@index_name.to_s).mappings_hash[@index_name])
    end

    # Attempts to get the GraphQL input type for a provided field.
    #
    # @param [String, Symbol] name The field name to lookup.
    # @return [GraphQL::ObjectType] Returns the GraphQL input type for the provided field.
    #
    # @raise [ArgumentError] If the field does not exist in the index, or there is no GraphQL type available for the field type.
    def type(name)
      name = name.to_sym if name.is_a?(String)
      field_type = @fields.fetch(name)

      # This will raise an exception if the type does not exist
      Yggdrasil::TypeRegistry.get(field_type).output

    rescue KeyError
      raise ArgumentError, "The field #{name} was not found on the index #{@index_name}."
    end

    # Fields in an ElasticSearch index do not have comments or descriptions unfortunately.
    #
    # @return [NilClass]
    def description(_name)
      nil
    end

    # Checks whether or not the provided field exists.
    #
    # @param [String, Symbol] name The field name to check.
    # @return [Boolean] Returns true if the field exists, false otherwise.
    def exists?(name)
      name = name.to_sym if name.is_a?(String)
      @fields.key?(name)
    end

    # Gets all of the field names contained in the backed index.
    #
    # @return [Array]
    def all
      @field_names ||= @fields.keys.map(&:to_s)
    end

    private

    # Normalizes an ES index.
    #
    # @param [Hash] index The index to normalize
    # @return [Array<Hash, Hash>] Returns a tuple:
    #   0 => The normalized fields and their corresponding types contained in the index.
    #   1 => Nested objects contained inside the index, keyed by the object name.
    def normalize_index(index)
      index = index.key?(:properties) ? index[:properties] : index

      # Conversion from ES types to supported database types
      string_types  = %w(keyword text).freeze
      integer_types = %w(long integer short).freeze
      float_types   = %w(double float half_float scaled_float).freeze

      normalized = {}
      nested     = {}
      index.each do |name, attributes|

        # Recursively convert nested objects
        if attributes[:type] == 'object'
          fields, deeply_nested = normalize_index(attributes)

          nested[name] = {
            type: :object,
            fields: fields,
            nested: deeply_nested
          }
          next
        end

        # Try to convert common ES types
        normalized[name] = case attributes[:type]
                             when *string_types
                               :string
                             when *integer_types
                               :integer
                             when *float_types
                               :float
                             else
                               attributes[:type].to_sym
                           end
      end

      [normalized, nested]
    end
  end
end
