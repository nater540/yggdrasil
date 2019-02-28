require 'yggdrasil'

module ApiQuery

  #
  #
  def api_query(query_string, variables: {}, context: {})
    ApiSchema.execute(
      query_string,
      context: context,
      variables: variables.deep_stringify_keys
    ).deep_symbolize_keys
  end
end

RSpec.configure do |config|
  config.include ApiQuery
end
