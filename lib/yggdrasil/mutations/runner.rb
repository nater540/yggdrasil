module Yggdrasil

  # This class is responsible for running actual mutations (applying, validating and saving changes)
  #
  # @since 1.0.0
  # @author Nate Strandberg
  #
  # @attr_reader [ActiveRecord::Base] record The initial record to apply changes to.
  # @attr_reader [Hash] inputs The incoming GraphQL arguments.
  # @attr_reader [FieldMap] field_map The field map for the record that should be changed.
  # @attr_reader [Array<Hash>] changes All changes made to the initial record, and any nested associations.
  class Runner
    include Validation

    attr_reader :record, :inputs, :field_map, :changes

    # Constructor
    #
    # @param [ActiveRecord::Base] record The initial record to apply changes to.
    # @param [GraphQL::Query::Arguments] inputs The incoming GraphQL arguments.
    # @param [FieldMap] field_map The field map for the record that should be changed.
    def initialize(record, inputs, field_map)
      @field_map  = field_map
      @record     = record
      @changes    = []

      # Convert the inputs to a hash object
      @inputs = inputs.to_h.deep_stringify_keys
    end

    # Apply mutation changes to the master record and all nested associations.
    #
    # @return [Array<Hash>] Returns all changes made to the provided record, and any nested associations.
    def apply_changes
      @changes = apply_changes_to_record(@record, @inputs, @field_map)
    end

    # Saves pending changes for the master record and all nested associations.
    #
    # @raise [ActiveRecord::RecordInvalid]
    # @raise [ActiveRecord::StatementInvalid]
    # @raise [ActiveRecord::RecordNotFound]
    # @raise [ActiveRecord::RecordNotUnique]
    # @raise [ActiveRecord::Rollback]
    def save!
      ActiveRecord::Base.transaction(requires_new: true) do
        changed_models.each do |model|
          next if model.destroyed?

          if model.marked_for_destruction?
            model.destroy
          else
            model.save!
          end
        end

        changed_models.reject(&:destroyed?)
      end
    end

    private

    def changed_models
      @changes.map { |change| change[:model_instance] }.uniq
    end

    # Applies mutation changes to a given record and all nested associations.
    #
    # @param [ActiveRecord::Base] record The record to apply changes to.
    # @param [Hash] inputs The incoming GraphQL inputs to apply.
    # @param [FieldMap] field_map The field map for this record.
    # @return [Array<Hash>] Returns all changes made to the provided record, and any nested associations.
    def apply_changes_to_record(record, inputs, field_map)
      changes = []

      # Get the input => attribute mapping
      inputs_to_attributes = field_map.mapping
      attributes_to_inputs = inputs_to_attributes.invert

      # Get all of the changed attributes for this record
      data = extract_values(inputs_to_attributes, inputs)
      data.each do |name, value|
        apply_field_value(record, attributes_to_inputs[name], name, value, changes)
      end

      # Loop over any nested associations and apply those changes as well (recursively calls `apply_changes_to_record`)
      field_map.nested.each do |nested|
        next if inputs[nested.name].nil?

        # Apply any necessary inputs for this record and store the changes
        nested_changes = handle_nested_association(record, inputs[nested.name], nested)
        nested_changes.each do |change|
          change[:input_path] = [nested.name] + Array.wrap(change[:input_path]) if change[:input_path].present?
          changes.push(change)
        end
      end

      changes
    end

    # Helper method that extracts attribute values.
    #
    # @param [Hash] mapping Hash containing the field name as a key, and the attribute for the value.
    # @param [Hash] inputs GraphQL input values.
    # @return [Hash] Returns a hash of attribute names and their corresponding input values.
    def extract_values(mapping, inputs)
      values = {}
      mapping.each do |name, attribute|
        next unless inputs.has_key?(name)
        values[attribute] = inputs[name]
      end
      values
    end

    # Helper method for applying a field change to a given model.
    #
    # @param [ActiveRecord:Base] model The model to apply the field value to.
    # @param [String] attribute The attribute name.
    # @param [Object] value The updated field value.
    # @param [Array] changes All of the changes made thus far.
    def apply_field_value(model, input_name, attribute, value, changes)
      return if model.public_send(attribute) == value

      model.public_send("#{attribute}=", value)
      changes.push(
        model_instance: model,
        attribute: attribute,
        input_path: input_name,
        action: model.new_record? ? :create : :update
      )
    end

    # Does the grunt work for individual nested associations.
    #
    # @param [ActiveRecord:Base] model The parent model to change.
    # @param [Hash] inputs The changes that should be made.
    # @param [FieldMap] field_map The field map for the nested association.
    # @return [Array<Hash>] Returns all of the changes made.
    def handle_nested_association(model, inputs, field_map)
      changes = []
      matches = match_inputs_to_models(model, field_map, inputs, changes)

      matches.each do |match|
        next if match[:child_model].nil? && match[:child_inputs].nil?
        nested_changes = apply_changes_to_record(match[:child_model], match[:child_inputs], field_map)

        # Handle deeply nested association indicies by prefixing the match index to the nested index
        if match[:input_path]
          nested_changes.select { |nested| nested[:input_path] }.each do |nested|
            nested[:input_path] = [match[:input_path]] + Array.wrap(nested[:input_path])
          end
        end

        changes.concat(nested_changes)
      end

      changes
    end

    # Matches nested inputs to the correct associated records & applies changes as necessary.
    #
    # @param [ActiveRecord:Base] model The parent model to change.
    # @param [FieldMap] field_map The field map for the incoming model(s).
    # @param [Hash] inputs The changes that should be made.
    # @param [Array] changes All of the changes made thus far.
    # @return [Array<Hash>] Returns all of the child models and their corresponding models.
    def match_inputs_to_models(model, field_map, inputs, changes)
      if field_map.has_many?
        inputs  = [] if inputs.nil?
        find_by = field_map.find_by

        # Grab any existing records
        associated_models = model.public_send(field_map.association)

        changes = if find_by.present?
                    # Attempt to link inputs using field names (handy for updates & deletes)
                    match_input_fields(field_map, inputs, associated_models, find_by, changes)
                  else
                    # Match the inputs to their (hopefully) respective models using input positions
                    match_input_positions(inputs, associated_models, changes)
                  end
        return changes
      end

      # This is a one-to-one association
      child_model = model.public_send(field_map.association)

      if inputs.nil? && child_model.present?

        # Existing record without any inputs, mark as destroyed (womp womp)
        child_model.mark_for_destruction
        changes.push(model_instance: child_model, action: :destroy)
      elsif child_model.nil? && !inputs.nil?

        id_field = field_map.id_field
        if id_field && inputs[id_field]
          association = model.association(field_map.association)
          child_model = association.klass.unscoped.where(id_field => inputs[id_field]).take!

          # Set the foreign key in the parent model
          model.public_send("#{association.reflection.foreign_key}=", inputs[id_field])
        else

          # Create a new record since it does not exist yet
          child_model = model.public_send("build_#{field_map.association}")
          changes.push(model_instance: child_model, action: :create)
        end
      end

      [{ child_model: child_model, child_inputs: inputs }]
    end

    # Attempts to link inputs using field names (handy for updates & deletes)
    #
    # @param [FieldMap] field_map The field map for the incoming models.
    # @param [Hash] inputs The changes that should be made to the associated models.
    # @param [Array] associated_models Any existing associated models.
    # @param [Hash] find_by The attribute fields to match inputs by.
    # @param [Array] changes All of the changes made thus far.
    # @return [Array<Hash>] Returns all of the child models and their corresponding models.
    def match_input_fields(field_map, inputs, associated_models, find_by, changes)
      # Index the associated models by the find_by keys so we can quickly match them to the incoming input data
      indexed_models = associated_models.index_by { |model| model.attributes.slice(*find_by.values) }

      # Index the input data by the find_by keys
      indexed_inputs = inputs.index_by { |input| input.slice(*find_by.keys) }

      # Now we need to convert the find_by input names to their corresponding attribute names
      #
      # @example We start with this hash inside `index_inputs`
      # {
      #   { "id" => "ca4f936b-6424-45c1-b1f4-cd954809269b", "quantityTotal" => 2000 } => {
      #     "id" => "ca4f936b-6424-45c1-b1f4-cd954809269b",
      #     "name" => "Good Media Tickets",
      #     "price" => 0.0,
      #     "quantityTotal" => 2000,
      #     "startDate" => "2017-08-01T03:00:57Z",
      #     "endDate" => "2017-08-01T05:00:57Z"
      #   },
      #   { "id" => "02e26716-2405-40a4-81c8-a080267f0ad7", "quantityTotal" => 18900 } => {
      #     "id" => "02e26716-2405-40a4-81c8-a080267f0ad7",
      #     "name" => "Meh Media Tickets",
      #     "price" => 1600.0,
      #     "quantityTotal" => 18900,
      #     "startDate" => "2017-08-01T03:00:57Z",
      #     "endDate" => "2017-08-01T05:00:57Z"
      #   }
      # }
      #
      # @example And we convert the above hash into this
      # {
      #   { "id" => "ca4f936b-6424-45c1-b1f4-cd954809269b", "quantity_total" => 2000 } => {
      #     "id" => "ca4f936b-6424-45c1-b1f4-cd954809269b",
      #     "name" => "Good Media Tickets",
      #     "price" => 0.0,
      #     "quantity_total" => 2000,
      #     "start_date" => "2017-08-01T03:00:57Z",
      #     "end_date" => "2017-08-01T05:00:57Z"
      #   },
      #   { "id" => "02e26716-2405-40a4-81c8-a080267f0ad7", "quantity_total" => 18900 } => {
      #     "id" => "02e26716-2405-40a4-81c8-a080267f0ad7",
      #     "name" => "Meh Media Tickets",
      #     "price" => 1600.0,
      #     "quantity_total" => 18900,
      #     "start_date" => "2017-08-01T03:00:57Z",
      #     "end_date" => "2017-08-01T05:00:57Z"
      #   }
      # }
      inputs_to_attributes = field_map.mapping
      indexed_inputs = indexed_inputs.map do |key, indexed_input|
        [key.map { |name, value| [inputs_to_attributes[name] || name, value] }.to_h, indexed_input]
      end

      # indexed_inputs = indexed_inputs.map do |key, indexed_input|
      #   key.map do |name, value|
      #     [inputs_to_attributes[name] || name, value]
      #   end
      # end

      indexed_inputs = indexed_inputs.to_h

      matches = []
      indexed_models.each do |key, child_model|
        matched_data = indexed_inputs[key]

        # If there is no data for this model, consider it deleted
        if matched_data.nil?
          child_model.mark_for_destruction
          # associated_models.destroy(child_model)
          changes.push(model_instance: child_model, action: :destroy)
          next
        end

        matches.push(child_model: child_model, child_inputs: matched_data, input_path: inputs.index(matched_data))
      end

      id_field = field_map.id_field

      # Create new records for any inputs that do not have models already created for them
      indexed_inputs.each do |key, child_inputs|
        next if indexed_models.include?(key)

        if id_field && child_inputs[id_field]
          existing_record = associated_models.unscoped.where(id_field.to_sym => child_inputs[id_field]).take!
          associated_models << existing_record
          matches.push(child_model: existing_record, child_inputs: child_inputs, input_path: inputs.index(child_inputs))
          next
        end

        child_model = associated_models.build
        changes.push(model_instance: child_model, action: :create)
        matches.push(child_model: child_model, child_inputs: child_inputs, input_path: inputs.index(child_inputs))
      end

      matches
    end

    # Matches incoming inputs to associated models by their position.
    # Note: This should only be used when creating new records, since it is not guaranteed to find the correct existing records.
    #
    # @param [Hash] inputs The changes that should be made to the associated models.
    # @param [Array] associated_models Any existing associated models.
    # @param [Array<Hash>] changes All of the changes made thus far.
    # @return [Array<Hash>] Returns all of the child models and their corresponding models.
    def match_input_positions(inputs, associated_models, changes)
      count = [associated_models.length, inputs.length].max

      matches = []
      count.times.zip(associated_models.to_a, inputs) do |(index, child_model, child_inputs)|
        if child_model.nil?
          child_model = associated_models.build
          changes.push(model_instance: child_model, action: :create)
        end

        if child_inputs.nil?
          child_model.mark_for_destruction
          changes.push(model_instance: child_model, action: :destroy)
          next
        end

        matches.push(child_model: child_model, child_inputs: child_inputs, input_path: index)
      end

      matches
    end
  end
end
