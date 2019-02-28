module Types
  TagType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'Tag'

    backed_by(model: Tag) do
      attribute :id
      attribute :name
    end
  end
end
