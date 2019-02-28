module Types
  UsersTagType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'UsersTag'

    backed_by(model: UsersTag) do
      attribute :id
      attribute :is_primary
    end

    field :tag, !TagType
  end
end
