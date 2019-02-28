module Yggdrasil

  # Contains all of the logic necessary to perform validation and error handling for GraphQL mutations.
  #
  # @since 1.0.0
  # @author Nate Strandberg
  #
  module Validation

    # Runs validation on all changes made to a given Runner instance.
    # @see Validation#validate
    #
    # @raise [ValidationError] If there are any validation errors.
    def validate!
      invalid_fields, unknown_errors = validate

      # noinspection RubyArgCount
      raise ValidationError.new(invalid_fields, unknown_errors, @inputs) unless invalid_fields.empty? && unknown_errors.empty?

      [invalid_fields, unknown_errors]
    end

    # Runs validation on all changes made to a given Runner instance.
    #
    # @example
    #   invalid_fields, unknown_errors = runner.validate
    #
    #   # `invalid_fields` is a hash with a string for each key indicating the input path to the error
    #   # and either an array of strings (in the case of multiple errors), or a single error message.
    #
    #   # `unknown_errors` is an array of hashes for errors that cannot be associated with any inputs in the field map.
    #   # Each hash in this array contains the following keys:
    #   # `modelType` (String) => The class name of the model that the error occurred on.
    #   # `modelId` (String, Integer) => The model Id (if applicable).
    #   # `attribute` (String) => The attribute (or association) for the error.
    #   # `message` (String) => The validation error message.
    #
    #
    # @return [Array<Hash, Array>] Returns a tuple:
    #   0 => Error messages keyed by the input path (EG: `tickets.1.name`)
    #   1 => Errors that cannot be associated with any input in the field map
    def validate
      invalid_fields = {}
      unknown_errors = []

      changed_models = @changes.group_by { |c| c[:model_instances] }
      changed_models.reject { |model, _| model.valid? }.each do |model, changes|

        # Build a hash to look up the path to a given attribute.
        #
        # The hash will use the attribute name (as a string) for the key,
        # each value will be composed of an array that contains the path to the failed input.
        #
        # @example
        # {
        #   "name" => [
        #     [0] "tickets",
        #     [1] 1,
        #     [2] "name"
        #   ],
        #   "price" => [
        #     [0] "tickets",
        #     [1] 1,
        #     [2] "price"
        #   ],
        #   "quantity_total" => [
        #     [0] "tickets",
        #     [1] 1,
        #     [2] "quantityTotal"
        #   ]
        # }
        attributes_to_fields = changes
                                 .select { |change| change[:attribute] && change[:input_paths] }
                                 .map { |change| [change[:attribute], change[:input_paths]] }
                                 .to_h

        # Loop over every error contained inside this model
        model.errors.each do |attribute, message|
          attribute = attribute.to_s if attribute.is_a?(Symbol)

          # Check if the look-up hash we created above contains this attribute
          if attributes_to_fields.include?(attribute)
            add_error(message, attributes_to_fields[attribute], invalid_fields)
          else

            # Error is with a field that was not present in the input, unfortunately that means we need to recursively attempt to find the proper place to insert the error
            path = input_path_for_attribute(@record, model, attribute, @inputs, @field_map)
            if path

              # Great Scott! The error path was found! Move along, move along...
              add_error(message, path, invalid_fields)
            else

              # Cannot find a field for this error, so label it as unknown :(
              unknown_errors.push(
                modelType: model.class.name,
                modelId: model.id,
                attribute: attribute,
                message: message
              )
            end
          end
        end
      end

      [invalid_fields, unknown_errors]
    end

    # Simple helper to add an error message to the invalid fields hash.
    #
    # @param [String] message The error message to add.
    # @param [String, Array] path The path to the input value.
    # @param [Hash] invalid_fields The current invalid field hash.
    def add_error(message, path, invalid_fields)
      current = invalid_fields
      path    = Array.wrap(path)

      # Create a place for this error if necessary
      path[0..-2].each do |ps|
        current = current[ps] ||= {}
      end

      # Ensure that the error goes into the correct position; note that `-1` will always be the association name (if applicable), or the field name
      key = path[-1]

      # If this field already has an error, then convert to an array & append the latest message
      if current[key].present?
        current[key] = current[key] unless current[key].is_a?(Array)
        current[key] << message
      else
        current[key] = message
      end
    end

    # Walks down the provided input and attempts to find the correct path for a given attribute error.
    #
    # @param [ActiveRecord::Base] starting_model The origin parent record.
    # @param [ActiveRecord::Base] target_model The target record that the error occurred on.
    # @param [String] attribute The attribute to look for.
    # @param [Hash] inputs Inputs provided by the caller.
    # @param [MutationFieldMap] field_map The current field map for `starting_model`.
    # @return [Array, NilClass] Returns either an array containing the path to the requested attribute, or nil if the attribute cannot be found.
    def input_path_for_attribute(starting_model, target_model, attribute, inputs, field_map)

      # Check if the error is on one of the current models inputs
      candidate_inputs = field_map.inputs.select { |input| input[:attribute] == attribute.to_s }
      candidate_inputs.each do |input|
        return Array.wrap(input[:name]) if starting_model == target_model
      end

      # Check if the error is on a nested association itself (the first result found will be returned)
      candidate_maps = field_map.nested.select { |nested| nested.association == attribute.to_s }
      candidate_maps.each do |map|
        return Array.wrap(map.name)
      end

      field_map.nested.each do |nested|
        next if inputs[nested.name].present? || starting_model.nil?

        # Attempt to find a model that matches the provided attribute (this is fairly costly unfortunately...)
        candidate_matches = match_inputs_to_models(starting_model, nested, inputs[nested.name], [])
        candidate_matches.each do |match|
          result = input_path_for_attribute(match[:child_model], target_model, attribute, match[:child_inputs], nested)
          next if result.nil?

          # Convert the result into an array, prepend the input path (if one exists) and finally prepend the association name
          path = Array.wrap(result)
          path.unshift(match[:input_path]) if match[:input_path].present?
          path.unshift(nested.name)
          return path
        end
      end

      # Womp Womp -- Attribute not found :(
      nil
    end
  end
end
