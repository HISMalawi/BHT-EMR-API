# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '~> 3.2.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.6'
# Use sqlite3 as the database for Active Record
gem 'mysql2'
# Use Puma as the app server
gem 'puma', '~> 6.3'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Json Web Token (JWT) for token based authentication
gem 'jwt'

# Use the browser gem to get browser information
gem 'browser'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development
gem 'passenger'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

gem 'composite_primary_keys'
gem 'rest-client'

gem 'test-unit'

gem 'rswag-api'
gem 'rswag-ui'

# gem 'emr_ohsp_interface', '~> 1.2'
# gem 'his_emr_api_lab', '~> 1.1.30'
# gem 'his_emr_api_radiology', '~> 0.0.8'

gem 'emr_ohsp_interface', '~> 2.2.3'
gem 'his_emr_api_lab', '~> 2.0.2'
# gem 'his_emr_api_lab', path: '../his_emr_api_lab'
# gem 'his_emr_api_radiology', '~> 1.0.9'

gem 'parallel', '~> 1.20.1'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'rswag-specs'
  gem 'spring'
end

group :development do
  gem 'listen'
  # gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'web-console', '>= 3.3.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'whenever', '~> 1.0'

# gems for reading excel and csv files
gem 'roo', '~> 2.8'
