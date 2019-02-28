module Mutations
  CreateUser = GraphQL::Relay::Mutation.define do
    # noinspection RubyArgCount
    name 'CreateUser'

    mutator = Yggdrasil::Mutator.create(self, User) do
      input :first_name
      input :last_name
      input :email
      input :password_digest, name: 'password'
      input :password_confirmation, type: types.String

      has_many :posts do
        input :subject
        input :body
        input :is_published
      end

      has_many :users_tags, name: :tags do
        input :is_primary

        belongs_to :tag, id_field: :id do
          input :id
          input :name
        end
      end
    end

    return_field :user, Types::UserType

    resolve ->(_obj, inputs, _ctx) do
      user = User.new

      runner = mutator.runner(user, inputs)
      runner.apply_changes
      runner.validate!
      runner.save!

      { user: user }
    end
  end
end
