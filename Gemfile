source 'https://rubygems.org'

gem 'mysql2'
gem 'pg'

branch = ENV.fetch('SOLIDUS_BRANCH', 'master')
gem "solidus", github: "solidusio/solidus", branch: branch
# Provides basic authentication functionality for testing parts of your engine
gem 'solidus_auth_devise'


gemspec
