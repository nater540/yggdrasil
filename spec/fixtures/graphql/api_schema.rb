GraphQL::Relay::ConnectionType.default_nodes_field = true

require_relative 'types/query_type'
require_relative 'types/mutation_type'

ApiSchema = GraphQL::Schema.define do
  query Types::QueryType
  mutation Types::MutationType

  max_depth 8
  max_complexity 220

  id_from_object ->(object, type_definition, _ctx) do
    GraphQL::Schema::UniqueWithinType.encode(
      type_definition.name,
      object.id,
      separator: '---'
    )
  end

  object_from_id ->(id, _ctx) do
    type_name, object_id = GraphQL::Schema::UniqueWithinType.decode(
      id,
      separator: '---'
    )
  end

  resolve_type ->(type, obj, ctx) do
    type_name = obj.class.name
    ApiSchema.types[type_name]
  end
end
