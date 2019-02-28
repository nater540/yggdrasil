# noinspection ALL
module Mutations
  RSpec.describe 'Update User (GraphQL)' do
    let(:query) do
      <<-GRAPHQL
      mutation Update($id: Int!, $firstName: String, $lastName: String, $email: String, $password: String, $posts: [UpdateUserPostInput!], $tags: [UpdateUserTagInput!]) {
        updateUser(input: { id: $id, firstName: $firstName, lastName: $lastName, email: $email, password: $password, posts: $posts, tags: $tags }) {
          user {
            id
            firstName
            lastName
            email
            posts {
              id
              subject
              body
            }
            tags {
              id
              isPrimary
              tag {
                id
                name
              }
            }
          }
        }
      }
      GRAPHQL
    end

    let(:fields) { %w[id firstName lastName email password posts tags] }

    context 'mutation arguments' do
      subject { UpdateUser.input_type.arguments }
      it { is_expected.to include(*fields) }
    end

    context 'updates an existing user' do
      let(:existing_user) do
        user = User.first
        return user unless user.nil?

        user = User.create(
          first_name: 'Zoku',
          last_name:  'Doge',
          email:      'supreme-leader@universe.com',
          password:   'ChewT0ys!'
        )

        # Add some literally amazing posts!
        user.posts.create(subject: 'Such Dig', body: 'Dig awesome stuff up in my yard!')
        user.posts.create(subject: 'Much Lazy', body: 'Sleep all day until owner gets home!')
        user.posts.create(subject: 'WOW!', body: 'OWNER HOME!!!')

        # Add brilliant tags that describe Zoku
        user.tags.create(name: 'Doge')
        user.tags.create(name: 'Japanese')
        user.tags.create(name: 'Meme')

        user
      end

      # Helper method for running the `updateUser` query using `existing_user` data.
      #
      # @param [Hash] params The params to update.
      # @return [Hash]
      def update_user(**params)
        params.merge!(id: existing_user.id)
        api_query(query, variables: params)
      end

      it 'updates firstName' do
        results = update_user(firstName: 'Glorious')
        expect(results.dig(:data, :updateUser, :user, :firstName)).to eq('Glorious')
      end

      it 'updates lastName' do
        results = update_user(lastName: 'Leader')
        expect(results.dig(:data, :updateUser, :user, :lastName)).to eq('Leader')
      end

      it 'updates posts' do
        posts_data = existing_user
                      .posts
                      .pluck(:id)
                      .map { |id| { id: id } }

        posts_data.second[:body] = 'Updated Body'

        # Add an adorable new post
        posts_data << { subject: 'Belly Rubs', body: 'Gosh they are so good!' }

        # Make an API call to update the user & dig the results back out
        results = update_user(posts: posts_data)
        updated_posts = results.dig(:data, :updateUser, :user, :posts)

        expect(updated_posts.count).to eq(posts_data.count)
      end

      it 'updates tags' do
        tags_data = existing_user
                      .users_tags
                      .pluck(:id)
                      .map { |id| { id: id } }

        # tags_data.second[:tag] = { name: 'Updated Name' }
        tags_data.second[:isPrimary] = true


        # Create tag & assign it using the `tagId` foreign key
        test_tag = Tag.create(name: 'Brand New Tag')
        tags_data << { tag: { id: test_tag.id } }

        # Create tag using the mutator
        tags_data << { tag: { name: 'WOW1' }, isPrimary: true }

        tags_data << { tag: { name: 'WOW2' }, isPrimary: false }

        tags_data << { tag: { name: 'WOW3' }, isPrimary: false }

        # Make an API call to update the user & dig the results back out
        results = update_user(tags: tags_data)
        updated_tags = results.dig(:data, :updateUser, :user, :tags)

        expect(updated_tags.count).to eq(tags_data.count)
      end
    end
  end
end
