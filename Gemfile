source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', platforms: :jruby
gem 'rubocop', '~> 0.62.0', require: false

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 4.5.0', '<= 4.5.1'
  gem 'jwe'
  gem 'mechanize'
end
