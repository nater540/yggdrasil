begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rspec/core/rake_task'
require File.expand_path('../spec/dummy/config/application', __FILE__)

Dummy::Application.load_tasks

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

Bundler::GemHelper.install_tasks
