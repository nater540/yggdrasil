require 'graphql'

DummySchema = GraphQL::Schema.define do
  query(Types::QueryType)
  mutation(Types::MutationType)

  rescue_from(ActiveRecord::RecordInvalid) do |error|
    error.message
  end

  rescue_from(ActiveRecord::RecordNotFound) do |error|
    'Could not find the record'
  end

  rescue_from(ActiveRecord::RecordNotUnique) do |error|
    error.message
  end

  rescue_from(ActiveRecord::Rollback) do |error|
    '--TBD--'
  end

  rescue_from(StandardError) do |error|
    error.inspect
  end

  rescue_from(ArgumentError) do |error|
    {
      message: error.message,
      backtrace: error.backtrace
    }.to_json
  end

  resolve_type ->(obj, _) do
    type_name = obj.class.name
    DummySchema.types[type_name]
  end
end
