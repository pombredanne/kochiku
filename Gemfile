source 'https://rubygems.org'

gem 'rails', '~> 4.0.2'
gem 'passenger', '4.0.10', group: :production
gem 'dynamic_form'

gem 'carrierwave'
gem 'mysql2'
gem 'symbolize'

gem 'haml-rails'
gem 'sass'
gem 'compass'

gem 'resque'
# The official resque-retry release has not merged https://github.com/lantins/resque-retry/pull/87
# which fixes an annoying Resque::Helpers deprecation warning
gem 'resque-retry', github: 'teeparham/resque-retry'

gem 'json' # used by resque

gem 'chunky_png'
gem 'cocaine'
gem 'awesome_print', require: false
gem 'nokogiri'
gem 'httparty'

gem 'bullet'
gem 'pry-rails'

gem 'colorize'

gem 'compass-rails'
gem 'jquery-rails'
gem 'sass-rails'
gem 'uglifier'

# therubyracer is a JS runtime required by execjs, which is in turn required
# by uglifier. therubyracer is not the fastest option but it is the most portable.
gem 'therubyracer'

group :test, :development do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'launchy'
end

group :development do
  gem 'capistrano', require: false
  gem 'quiet_assets'
  gem 'rvm-capistrano', require: false
  gem 'thin'
  gem 'rails-erd'
end

group :test do
  gem 'webmock', require: false
  gem 'capybara'
end
