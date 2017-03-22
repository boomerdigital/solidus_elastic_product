# encoding: UTF-8
$:.push File.expand_path('../lib', __FILE__)
require 'solidus_elastic_product/version'

Gem::Specification.new do |s|
  s.name        = 'solidus_elastic_product'
  s.version     = SolidusElasticProduct::VERSION
  s.summary     = 'High performance Elastic Search data syncronization extension for Solidus'
  s.description = 'Uses a product state table to sync changes with Elastic Search in background through workers.'
  s.license     = 'BSD-3-Clause'

  s.author      = 'Eric Anderson; Martin Tomov'
  # s.email     = 'you@example.com'
  # s.homepage  = 'http://www.example.com'

  s.files = Dir["{app,config,db,lib}/**/*", 'LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'elasticsearch-model'
  s.add_dependency 'solidus_core'

  s.add_development_dependency 'capybara'
  s.add_development_dependency 'poltergeist'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'sass-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'log_buddy'
  s.add_development_dependency 'awesome_print'
end
