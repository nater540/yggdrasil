module Yggdrasil

  # Custom exception that is raised if there are any validation errors.
  # Formats errors in a similar style to the GraphQL::ExecutionError when serialized to JSON.
  #
  # @since 1.0.0
  # @author Nate Strandberg
  #
  class ValidationError < GraphQL::ExecutionError

    # Constructor
    #
    # @param [Hash] invalid_fields Hash with a string for each key indicating the input path to the error
    #   and either an array of strings (in the case of multiple errors), or a single error message.
    # @param [Array] unknown_errors An array of hashes for errors that cannot be associated with any inputs in the field map.
    # @param [Hash] values Optional GraphQL input values so the caller can rebuild HTML forms.
    def initialize(invalid_fields, unknown_errors, values = nil)
      @invalid_fields = invalid_fields
      @unknown_errors = unknown_errors
      @values         = values
    end

    # Converts this exception to a hash and formats errors in a similar style to the GraphQL::ExecutionError.
    #
    # @return [Hash] Returns a hash that can be serialized to JSON.
    def to_h
      {
        message: 'Some of your changes could not be saved.',
        value: @values,
        problems: normalize_problems(@invalid_fields),
        unknown: @unknown_errors
      }
    end

    private

    # Normalizes invalid field errors to something presentable when serialized to JSON.
    #
    # @param [Hash] problems The problems to normalize.
    # @param [Array<String>] path The current path to this set of problems (used for nested associations)
    # @return [Array<Hash>] Returns an array of hashes, each containing the `path` to a given problem and an explanation.
    def normalize_problems(problems, path: [])
      normalized = []

      problems.each do |field, problem|
        if problem.is_a?(Hash)
          normalized.concat(normalize_problems(problem, path: path + Array.wrap(field)))
          next
        end

        normalized << {
          path: path + field,
          explanation: problem
        }
      end

      normalized
    end
  end
end
