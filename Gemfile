source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', platforms: :jruby
gem 'rubocop', '~> 0.62.0', require: false
group :test, :unit_test do
  gem 'simplecov', '~> 0.21.0', require: false
end
group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 3.0.0', '<= 3.0.1'
  gem 'jwe'
  gem 'mechanize'
end
