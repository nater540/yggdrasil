module Mutations
  UpdateUser = GraphQL::Relay::Mutation.define do
    # noinspection RubyArgCount
    name 'UpdateUser'

    mutator = Yggdrasil::Mutator.create(self, User) do
      input :id, required: true
      input :first_name
      input :last_name
      input :email
      input :password_digest, name: 'password'
      input :password_confirmation, type: types.String

      has_many :posts, find_by: :id do
        input :id
        input :subject
        input :body
        input :is_published
      end

      has_many :users_tags, name: :tags, find_by: [:id, :tag] do
        input :id
        input :is_primary

        belongs_to :tag, id_field: :id, find_by: [:id, :name] do
          input :id
          input :name
        end
      end
    end

    return_field :user, Types::UserType

    resolve ->(_obj, inputs, _ctx) do
      user = User.find(inputs[:id])

      runner = mutator.runner(user, inputs)
      runner.apply_changes
      runner.validate!
      runner.save!

      { user: user.reload }
    end
  end
end
