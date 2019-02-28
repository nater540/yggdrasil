require 'rspec/graphql_matchers'

RSpec.configure do |config|
  config.include RSpec::GraphqlMatchers::TypesHelper
end
