module Yggdrasil

  # Assists with creating GraphQL types & fields from ActiveRecord models or Chewy Indicies.
  #
  # @author Nate Strandberg
  # @since 1.0.0
  #
  # @attr_reader [GraphQL::ObjectType] object_type
  # @attr_reader [ActiveRecordDelegator, ChewyIndexDelegator] backed_by
  #
  # @example Backed by an active record model
  #   UserType = GraphQL::ObjectType.define do
  #     name 'User'
  #
  #     backed_by(model: User) do
  #       attribute :first_name
  #       attribute :last_name
  #       attribute :email
  #     end
  #   end
  #
  # @example Backed by a ElasticSearch Chewy index
  #   UserType = GraphQL::ObjectType.define do
  #     name 'User'
  #
  #     backed_by(index: UsersIndex) do
  #       attribute :first_name
  #       attribute :last_name
  #       attribute :email
  #     end
  #   end
  #
  class BackedBy
    attr_reader :object_type, :backed_by

    # Constructor
    #
    # @param [GraphQL::ObjectType] object_type The ObjectType to attach to.
    # @param [ActiveRecord::Base] model Should be provided if you intend to use an ActiveRecord model and *not* a Chewy index.
    # @param [Chewy::Index] index Should be provided if you intend to use a Chewy index and *not* an ActiveRecord model.
    # @param [String, Symbol] index_name Optional name for the Chewy index to use.
    # @param [Hash] options Additional options to pass in.
    def initialize(object_type, model: nil, index: nil, index_name: nil, options: {})
      @object_type = object_type

      @backed_by = if model.present?
                     model = model.to_s.classify.constantize unless model.is_a?(Class)
                     ActiveRecordDelegator.new(model, options)
                   elsif index.present?
                     begin
                       require 'chewy_index_delegator' unless defined?(Chewy)
                     rescue Gem::LoadError => err
                       raise Gem::LoadError, "Attempted to load a Chewy Index, however the gem is not loaded. Add `gem '#{err.name}', '#{err.requirement}'` to your Gemfile and ensure its version is at the minimum required by Yggdrasil."
                     rescue LoadError => err
                       raise LoadError, 'Could not load `chewy_index_delegator.rb`.', err.backtrace
                     end

                     # Make it so number one
                     ChewyIndexDelegator.new(index, index_name, options)
                   else

                     # Ruh roh... Something smells fishy :|
                     raise ArgumentError, 'Must specify either a `model` or `index` argument.'
                   end
    end

    # @return [GraphQL::Define::TypeDefiner]
    def types
      GraphQL::Define::TypeDefiner.instance
    end

    # Declares a new GraphQL field via an attribute.
    #
    # @param [String, Symbol] attribute The attribute name (model column or index field)
    # @param [Hash] options Options for this new GraphQL field.
    # @option options [String, Symbol] :name Optional GraphQL field name (will camelCase the attribute argument if this is not provided)
    # @option options [GraphQL::BaseType] :type Optional GraphQL type for this field.
    # @option options [Object, GraphQL::Function] :function The function used to derive this field.
    # @option options [Boolean] :required Whether or not this field should be required.
    # @option options [String] :description The description for this field.
    # @option options [String] :deprecation_reason The client-facing reason why this field is deprecated (if present, the field is deprecated).
    # @option options [Numeric, Proc] :complexity The complexity for this field (default: 1), as a constant or a proc like `->(query_ctx, args, child_complexity) { }`
    def attribute(attribute, **options)
      options.assert_valid_keys(:name, :type, :function, :required, :description, :deprecation_reason, :complexity)
      attribute = attribute.to_sym if attribute.is_a?(String)

      description = options[:description] || @backed_by.description(attribute)
      field_name  = options[:name]        || attribute.to_s.camelize(:lower)
      field_type  = options[:type]        || @backed_by.type(attribute)

      # Convert the type to non-null if it is marked as required
      field_type = field_type.to_non_null_type if options[:required]

      # Go forth and declare the new field!
      field = GraphQL::Field.define do
        name field_name
        type field_type
        description description
        function options[:function] || nil
        complexity options[:complexity] || 1
        deprecation_reason options[:deprecation_reason] if options.include?(:deprecation_reason)
      end

      # Try to use the built-in resolvers (either `property` or `hash_key`)
      if @backed_by.is_a?(ActiveRecordDelegator)
        field.property = attribute
      else
        field.hash_key = attribute
      end

      field = yield(field) if block_given?

      # Add the new field and move along, move along...
      @object_type.fields[field_name] = field
    end

    # Creates GraphQL fields for all model columns / index fields (depending on the backing)
    #
    # @example Add fields for all columns except the primary key:
    #   all_fields(exclude: :id)
    #
    # @example Add fields for all columns except two:
    #   all_fields(exclude: %i(id is_admin))
    #
    # @example Change the name of one field:
    #   all_fields(options: {
    #     password_digest: { name: 'password' }
    #   })
    #
    #
    # @param [Array] exclude Fields to exclude.
    # @param [Hash] options Field options keyed by the their name.
    def all_fields(exclude: [], options: {})
      options.stringify_keys!
      exclude = Array.wrap(exclude).map(&:to_s)

      @backed_by.all.without(*exclude).each do |name|

        # Create an field for this attribute and pass any provided options
        attribute(name, **options[name] || {})
      end
    end
  end
end
