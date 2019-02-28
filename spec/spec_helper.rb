$LOAD_PATH.unshift File.dirname(__FILE__)

ENV['RAILS_ENV'] ||= 'test'

require 'faker'
require 'graphql'
require 'rails/all'
require 'database_cleaner'
require 'yggdrasil'

require 'coveralls'
Coveralls.wear!

FIXTURES_DIR = "#{File.dirname(__FILE__)}/fixtures"
GRAPHQL_DIR  = "#{FIXTURES_DIR}/graphql"

autoload :ApiSchema, "#{GRAPHQL_DIR}/api_schema"

module Mutations
  autoload :CreateUser, "#{GRAPHQL_DIR}/mutations/create_user"
  autoload :UpdateUser, "#{GRAPHQL_DIR}/mutations/update_user"
end

module Types
  TYPES_DIR = "#{GRAPHQL_DIR}/types"
  autoload :MutationType, "#{TYPES_DIR}/mutation_type"
  autoload :PostType, "#{TYPES_DIR}/post_type"
  autoload :QueryType, "#{TYPES_DIR}/query_type"
  autoload :TagType, "#{TYPES_DIR}/tag_type"
  autoload :UserType, "#{TYPES_DIR}/user_type"
  autoload :UsersTagType, "#{TYPES_DIR}/users_tag_type"
end

Dir["#{File.dirname(__FILE__)}/fixtures/models/*.rb"].each { |file| require file }
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.mock_with :rspec
  config.order = :random

  config.before(:context) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

end

# Setup fake `Rails.root`
def stub_rails_root(path = './spec/fixtures')
  allow(Rails).to receive(:root).and_return(Pathname.new(path))
end

# Setup fake `Rails.env`
def stub_rails_env(env = 'development')
  allow(Rails).to receive(:env).and_return(env)
end
