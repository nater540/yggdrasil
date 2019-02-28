# coding: utf-8

$:.push File.expand_path('../lib', __FILE__)

require 'yggdrasil/version'

Gem::Specification.new do |spec|
  spec.name     = 'yggdrasil'
  spec.version  = Yggdrasil::VERSION
  spec.authors  = ['Nate Strandberg']
  spec.email    = ['nater540@gmail.com']

  spec.license      = 'MIT'
  spec.summary      = ''
  spec.homepage     = ''
  spec.description  = ''

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'exe'
  spec.test_files    = Dir['spec/**/*']
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'graphql', '<= 1.7.10'
  spec.add_dependency 'activerecord', '~> 5.2', '>= 5.2.0'
  spec.add_dependency 'activesupport', '~> 5.2', '>= 5.2.0'

  # Optional ElasticSearch support
  spec.add_development_dependency 'chewy', '>= 0.10.1'

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'github-markup'

  spec.add_development_dependency 'database_cleaner', '~> 1.7'

  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'bcrypt'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency 'rails', '~> 5.2'
  spec.add_development_dependency 'rspec-graphql_matchers'
  spec.add_development_dependency 'generator_spec', '~> 0.9.3'
end
