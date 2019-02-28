module Types
  PostType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'Post'

    backed_by(model: Post) do
      attribute :id
      attribute :subject
      attribute :body
      attribute :is_published
    end
  end
end
