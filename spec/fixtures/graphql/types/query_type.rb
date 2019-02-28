require_relative 'post_type'
require_relative 'user_type'

module Types
  QueryType = GraphQL::ObjectType.define do
    # noinspection RubyArgCount
    name 'Query'
    description 'One query to rule them all, one query to find them, One query to bring them all and in the darkness bind them.'

    # Used by Relay to lookup objects by UUID
    field :node, GraphQL::Relay::Node.field

    field :user, UserType do
      argument :id, !types.ID
      resolve ->(_, args, _) do
        User.find(args['id'])
      end
    end

    field :users, types[UserType] do
      resolve ->(_, _, _) do
        User.all
      end
    end

    field :post, PostType do
      argument :id, !types.ID
      resolve ->(_, args, _) do
        Post.find(args['id'])
      end
    end

    field :posts, types[PostType] do
      resolve ->(_, _, _) do
        Post.all
      end
    end
  end
end
