module Types
  MutationType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'Mutation'

    field :createUser, field: Mutations::CreateUser.field
    field :updateUser, field: Mutations::UpdateUser.field
  end
end
