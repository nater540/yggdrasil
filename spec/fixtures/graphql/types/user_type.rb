module Types
  UserType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'User'

    backed_by(model: User) do
      attribute :id
      attribute :first_name
      attribute :last_name
      attribute :email
      attribute :password_digest, name: 'password'
    end

    field :posts, !types[PostType]
    field :tags,  !types[UsersTagType]

    field :tags, !types[UsersTagType] do
      resolve -> (user, _, _) { user.users_tags }
    end
  end
end
