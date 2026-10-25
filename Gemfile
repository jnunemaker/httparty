source 'https://rubygems.org'
gemspec

gem 'base64'
gem 'rake'
gem 'mongrel',  '1.2.0.pre2'
gem 'cgi' # mongrel needs the full CGI class, which Ruby 4.0 dropped
gem 'json'

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test do
  gem 'rexml'
  gem 'rspec',    '~> 3.4'
  gem 'simplecov', require: false
  gem 'aruba'
  gem 'cucumber', '~> 2.3'
  gem 'ostruct' # cucumber 2.x needs it; Ruby 4.0 no longer ships it as a default gem
  gem 'webmock'
  gem 'addressable'
end

group :development, :test do
  gem 'pry'
end
