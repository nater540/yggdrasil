# noinspection ALL
module Mutations
  RSpec.describe 'Create User (GraphQL)' do
    let(:query) do
      <<-GRAPHQL
      mutation Create($firstName: String!, $lastName: String!, $email: String!, $password: String!, $posts: [CreateUserPostInput!], $tags: [CreateUserTagInput!]) {
        createUser(input: { firstName: $firstName, lastName: $lastName, email: $email, password: $password, posts: $posts, tags: $tags }) {
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

    let(:fields) { %w[firstName lastName email password posts tags] }

    context 'mutation arguments' do
      subject { CreateUser.input_type.arguments }
      it { is_expected.to include(*fields) }
    end

    context 'creates a new user' do
      let(:test_user) do
        test_tag = Tag.create(name: 'Fabulous')

        {
          firstName: 'Nate',
          lastName:  'Strandberg',
          email:     'nater540@gmail.com',
          password:  'kitt3ns!',
          posts: [
            {
              subject: 'Supercalifragilisticexpialidocious',
              body: 'I like turtles',
              isPublished: true
            }
          ],
          tags: [
            {
              isPrimary: true,
              tag: { name: 'Bounce' }
            },
            {
              isPrimary: false,
              tag: { name: 'Twister' }
            },
            {
              isPrimary: false,
              tag: {
                id: test_tag.id
              }
            }
          ]
        }
      end

      subject { api_query(query, variables: test_user) }
      let(:errors) { subject[:errors] || [] }
      let(:user)   { subject.dig(:data, :createUser, :user) }

      it 'has zero errors' do
        expect(errors.count).to eq(0)
      end

      it 'has three tags' do
        expect(user[:tags].count).to eq(3)
      end

      it 'has one post' do
        expect(user[:posts].count).to eq(1)
      end
    end
  end
end
