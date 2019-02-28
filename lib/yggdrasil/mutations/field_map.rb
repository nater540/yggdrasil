module Yggdrasil

  # This class maintains a mapping of database attributes to GraphQL inputs.
  #
  # @since 1.0.0
  # @author Nate Strandberg
  #
  # @attr_reader [ActiveRecord::Base] model
  # @attr_reader [Array<Hash>] inputs
  # @attr_reader [Hash] mapping
  # @attr_reader [Array<FieldMap>] nested
  # @attr_reader [String] name
  # @attr_reader [String] description
  # @attr_reader [String] association
  # @attr_reader [Boolean] required
  # @attr_reader [Array<String>] find_by
  # @attr_reader [Symbol] id_field
  class FieldMap
    include Enumerable

    attr_reader :model, :inputs, :mapping, :nested, :name, :description, :association, :required, :find_by, :id_field

    # Constructor
    #
    # @param [ActiveRecord::Base] model Association model.
    # @param [Hash] options Options for this field map.
    # @option options [String, Symbol] :name The name for this field map.
    # @option options [String] :description Optional description to be used for this association input type.
    # @option options [Array<Symbol>] :find_by Optional attribute to match inputs by; automatically creates GraphQL inputs for each find_by item.
    def initialize(model, **options)
      default_options = { macro: nil, association: nil, name: nil, description: nil, find_by: nil, id_field: nil, required: false, defaults: {} }
      options.reverse_merge!(default_options)
      options.assert_valid_keys(:macro, :association, :name, :description, :find_by, :id_field, :required, :defaults)

      @association = options[:association]
      @description = options[:name]
      @required    = options[:required]
      @id_field    = options[:id_field]
      @defaults    = options[:defaults]
      @macro       = options[:macro]
      @name        = options[:name].to_sym

      @id_field = @id_field.to_s if @id_field.is_a?(Symbol)

      @options = options
      @find_by = {}
      @mapping = {}
      @nested  = []
      @inputs  = []
      @model   = model

      find_by = Array.wrap(options[:find_by])

      # TODO: This causes a bug with deeply nested creation mutations since it causes Runner to call `match_input_fields` instead of `match_input_positions`
      # if options[:id_field].present?
      #   find_by << options[:id_field] unless find_by.include?(options[:id_field])
      # end

      # Add any find_by fields as inputs
      find_by.each do |field|
        field = field.to_s if field.is_a?(Symbol)
        name  = field.camelize(:lower)

        # Add an input for this find by field
        # input(field, name: name)

        @find_by[name] = field
      end
    end

    delegate :each, :empty?, :select, :detect, to: :@inputs

    # Checks whether or not a given input exists.
    #
    # @param [String, Symbol] name
    # @return [Boolean]
    def exists?(name)
      @inputs.detect { |input| input[:name] == name.to_s }.present?
    end

    # Checks whether or not this is a `has_many` nested association.
    #
    # @return [Boolean]
    def has_many?
      @macro == :belongs_to
    end

    # Checks whether or not this is a `has_one` nested association.
    #
    # @return [Boolean]
    def has_one?
      @macro == :has_one
    end

    # Checks whether or not this is a `belongs_to` nested association.
    #
    # @return [Boolean]
    def belongs_to?
      @macro == :belongs_to
    end

    # @return [GraphQL::Define::TypeDefiner]
    def types
      GraphQL::Define::TypeDefiner.instance
    end

    # Creates inputs for all of the columns in this model.
    #
    # @example Add inputs for all columns except the primary key
    #   all_columns(exclude: :id)
    #
    # @example Add inputs for all columns except two
    #   all_columns(exclude: %i(id is_admin))
    #
    # @example Change the name of one column
    #   all_columns(options: {
    #     password_digest: { name: 'password' }
    #   })
    #
    #
    # @param [Array] exclude Column names to exclude.
    # @param [Hash] options Input options keyed by the column name.
    # @return [self]
    def all_columns(exclude: [], options: {})
      options.stringify_keys!
      exclude = Array.wrap(exclude).map(&:to_s)

      columns = @model.column_names.without(*exclude)
      columns.each do |column|

        # Create an input for this attribute & pass any provided options
        input(column, **options[column] || {})
      end
      self
    end

    # Adds a single input field.
    #
    # @example Add a simple field:
    #   input :first_name # This creates a GraphQL input field named "firstName"
    #
    # @example Add a required field with a description
    #   input :email, required: true, description: 'Your real email address.' # This creates a GraphQL input field named "email" that is required
    #
    # @example Add fields with a block (Pointless example, but you get the drift...)
    #   input :favorite_cartoon do |obj|
    #     obj[:default_value] = 'Looney Tunes'
    #     obj
    #   end
    #
    #   input :favorite_character do |obj|
    #     obj[:default_value] = 'Taz'
    #     obj
    #   end
    #
    #
    # @param [String, Symbol] attribute The attribute to add.
    # @param [Hash] options Options for this input.
    # @option options [String, Symbol] :name Optional GraphQL field name (will camelCase the attribute argument if this is not provided)
    # @option options [String, Symbol] :as Optional name of this argument inside `resolve` functions.
    # @option options [Boolean] :required Whether or not this field should be required (If this is left null, then a check is done on the model itself)
    # @option options [String] :description Optional description for this field. The model column comment will be used if this is not provided.
    # @option options [GraphQL::BaseType] :type Optional GraphQL type for this field.
    # @option options [Proc] :prepare Optional function to prepare this argument's value before `resolve` functions are called.
    # @option options [Object] :default_value Optional default value to use.
    # @return [self]
    def input(attribute, **options)
      options.assert_valid_keys(:name, :as, :required, :description, :type, :prepare, :default_value)
      attribute = attribute.to_s if attribute.is_a?(Symbol)

      # Attempt to get the correct GraphQL type for the attribute
      type = options.fetch(:type) do
        attribute_type = @model.type_for_attribute(attribute)
        if attribute_type.type.nil?
          raise ArgumentError, "The field #{attribute} was not found on the model #{@model.name}"
        end

        # This will raise an exception if the type does not exist
        input_type = Yggdrasil::TypeRegistry.get(attribute_type.type).input

        if attribute_type.class.name.ends_with?('Field')
          input_type = input_type.to_list_type
        end
        input_type
      end

      # camelCase the attribute name unless the input name was provided
      name = options.fetch(:name) { attribute.camelize(:lower) }

      # Store an entry for quick reference between attributes and their GraphQL names
      @mapping[name] = attribute

      input = {
        type:        type,
        name:        name,
        attribute:   attribute,
        required:    options.fetch(:required) { @defaults[:required] || required?(attribute) },
        description: options.fetch(:description) { @model.columns_hash[attribute]&.comment }
      }

      # Add optional input keys as necessary
      input[:default_value] = options[:default_value] if options.key?(:default_value)
      input[:prepare]       = options[:prepare]       if options.key?(:prepare)
      input[:as]            = options[:as]            if options.key?(:as)

      input = yield(input) if block_given?
      inputs.push(input)
      self
    end

    # Adds a has_many association.
    #
    # @example
    #   has_many :turtles do
    #     input :like, type: types.Boolean
    #   end
    #
    #
    # @param [String, Symbol] association The association name.
    # @param [Hash] options Options for this association.
    # @option options [String, Symbol] :name The name for this association. Defaults to the association name camelCased.
    # @option options [Boolean] :required Whether or not this association is required.
    # @option options [String] :description Optional description to be used for this association input type.
    # @option options [Array<Symbol>] :find_by Optional attribute to match inputs by; automatically creates GraphQL inputs for each find_by item.
    def has_many(association, **options, &block)
      create_association(:has_many, association, options, &block)
    end

    # Adds a has_one association.
    #
    # @example
    #   has_one :puppy do
    #     input :name, default_value: 'San-Zoku'
    #     input :breed, default_value: 'Shiba Inu'
    #     input :is_adorable, default_value: true
    #   end
    #
    #
    # @param [String, Symbol] association The association name.
    # @param [Hash] options Options for this association.
    # @option options [String, Symbol] :name The name for this association. Defaults to the association name camelCased.
    # @option options [Boolean] :required Whether or not this association is required.
    # @option options [String] :description Optional description to be used for this association input type.
    # @option options [Array<Symbol>] :find_by Optional attribute to match inputs by; automatically creates GraphQL inputs for each find_by item.
    def has_one(association, **options, &block)
      create_association(:has_one, association, options, &block)
    end

    # Adds a belongs_to association.
    # Note: If you declare the association as not required (default), then an input for the association foreign key will automatically be created.
    #
    # @example
    #   belongs_to :role do
    #     input :name, required: true
    #     input :is_admin, default_value: false
    #   end
    #
    #
    # @param [String, Symbol] association The association name.
    # @param [Hash] options Options for this association.
    # @option options [String, Symbol] :name The name for this association. Defaults to the association name camelCased.
    # @option options [Boolean] :required Whether or not this association is required.
    # @option options [String] :description Optional description to be used for this association input type.
    # @option options [Array<Symbol>] :find_by Optional attribute to match inputs by; automatically creates GraphQL inputs for each find_by item.
    def belongs_to(association, **options, &block)
      create_association(:belongs_to, association, options, &block)
    end

    private

    # Checks whether or not a given field is required.
    #
    # @param [String] field The field to check.
    # @return [Boolean] Returns true if the field is required, false otherwise.
    def required?(field)

      # If the field can be null, then assume it is not required
      return false if @model.columns_hash[field]&.null

      # Check for a presence validator on the association
      return true if @model.validators_on(field)
                       .select { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
                       .reject { |v| v.options.include?(:if) || v.options.include?(:unless) }
                       .any?

      # Check if this is a belongs_to foreign key
      reflection = @model.reflect_on_association(field)
      reflection&.macro == :belongs_to
    end

    # Creates a new nested association.
    #
    # @param [Symbol] macro The association macro (has_one, has_many, belongs_to)
    # @param [String, Symbol] association The association name.
    # @param [Hash] options Options for this association.
    # @option options [String, Symbol] :name The name for this association. Defaults to the association name camelCased.
    # @option options [Boolean] :required Whether or not this association is required.
    # @option options [String] :description Optional description to be used for this association input type.
    # @option options [Array<Symbol>] :find_by Optional attribute to match inputs by; automatically creates GraphQL inputs for each find_by item.
    def create_association(macro, association, **options, &block)
      association = association.to_s if association.is_a?(Symbol)

      # Shove in additional fabulous options!
      options.reverse_merge!(macro: macro, name: association.camelize(:lower), association: association)

      # Reflection on the association & ensure that the world is still round (eg: make sure the association is what we are expecting)
      reflection = @model.reflect_on_association(association)
      raise ArgumentError, "Could not find association `#{association}` on `#{@model.name}`" unless reflection
      raise ArgumentError, "Association `#{association}` on `#{@model.name}` is polymorphic and not supported" if reflection.polymorphic?
      raise ArgumentError, "Association `#{association}` on `#{@model.name}` expected to be `#{macro}`, but was `#{reflection.macro}` instead" unless reflection.macro == macro

      # Automatically add the foreign key as an input for optional belongs_to associations
      # if macro == :belongs_to && !options[:required]
      #   input(reflection.foreign_key, type: types.ID)
      # end

      if macro == :has_many && options.key?(:id_field)
        options[:id_field] = :id
      end

      field_map = FieldMap.new(reflection.klass, options)
      field_map.instance_exec(&block) if block_given?
      nested.push(field_map)
      self
    end
  end
end
