module Yggdrasil

  # Decorator class for ActiveRecord model classes.
  #
  # @author Nate Strandberg
  # @since 1.0.0
  #
  class ActiveRecordDelegator < SimpleDelegator

    # Constructor
    def initialize(obj, options = {})
      super(obj)
    end

    # Attempts to get the GraphQL input type for a provided column.
    #
    # @param [String, Symbol] name The column name to lookup.
    # @return [GraphQL::ObjectType] Returns the GraphQL input type for a provided column.
    #
    # @raise [ArgumentError] If the column does not exist in the model, or there is no GraphQL type available for the column type.
    def type(name)
      name = name.to_s if name.is_a?(Symbol)
      attribute_type = __getobj__.type_for_attribute(name)

      if attribute_type.type.nil?
        raise ArgumentError, "The field #{name} was not found on the model #{__getobj__.name}"
      end

      # This will raise an exception if the type does not exist
      input_type = Yggdrasil::TypeRegistry.get(attribute_type.type).output

      if attribute_type.class.name.ends_with?('Array')
        input_type = input_type.to_list_type
      end
      input_type
    end

    # Attempts to get a comment for the provided column.
    #
    # @param [String, Symbol] name The column name to lookup.
    # @return [String, NilClass] Returns the column comment if one exists, nil otherwise.
    def description(name)
      __getobj__.columns_hash[name.to_s]&.comment
    end

    # Checks whether or not the provided column exists.
    #
    # @param [String, Symbol] name The column name to check.
    # @return [Boolean] Returns true if the column exists, false otherwise.
    def exists?(name)
      name = name.to_s if name.is_a?(Symbol)
      __getobj__.columns_hash.key?(name)
    end

    # Gets all of the column names contained in the backed model.
    #
    # @return [Array]
    def all
      __getobj__.column_names
    end
  end
end
