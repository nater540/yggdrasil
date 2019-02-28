require 'yggdrasil/version'
require 'graphql'

begin
  require 'awesome_print'
rescue LoadError
end

# Yggdrasil is an immense mythical tree that connects the nine worlds in Norse cosmology.
module Yggdrasil
  # Path to the root "yggdrasil" directory
  LIBRARY_PATH = File.join(File.dirname(__FILE__), 'yggdrasil')

  autoload :TypeRegistry, File.join(LIBRARY_PATH, 'type_registry')

  # Path to the root "mutations" directory
  MUTATIONS_PATH = File.join(LIBRARY_PATH, 'mutations')
  autoload :Runner,          File.join(MUTATIONS_PATH, 'runner')
  autoload :Mutator,         File.join(MUTATIONS_PATH, 'mutator')
  autoload :FieldMap,        File.join(MUTATIONS_PATH, 'field_map')
  autoload :Validation,      File.join(MUTATIONS_PATH, 'validation')
  autoload :ValidationError, File.join(MUTATIONS_PATH, 'validation_error')

  # Path to the root "object_types" directory
  TYPES_PATH = File.join(LIBRARY_PATH, 'object_types')
  autoload :BackedBy,              File.join(TYPES_PATH, 'backed_by')
  autoload :ActiveRecordDelegator, File.join(TYPES_PATH, 'active_record_delegator')

  module Resolvers
    RESOLVERS_PATH = File.join(LIBRARY_PATH, 'resolvers')
    autoload :Base,   File.join(RESOLVERS_PATH, 'base')
    autoload :Search, File.join(RESOLVERS_PATH, 'search')
  end

  # Wrapper method for including resolver functionality.
  #
  # @return [Resolvers::Base]
  def self.resolvable
    Resolvers::Base
  end
end

GraphQL::ObjectType.accepts_definitions(
  backed_by: ->(object_type, model: nil, index: nil, index_name: nil, options: {}, &block) do
    backed_by = Yggdrasil::BackedBy.new(object_type, model: model, index: index, index_name: index_name, options: options)
    backed_by.instance_exec(&block)
  end
)
