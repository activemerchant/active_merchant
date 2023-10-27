source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', platforms: :jruby
gem 'rubocop', '~> 0.72.0', require: false

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 4.14.0'
  gem 'jose', '~> 1.1.3'
  gem 'jwe'
  gem 'mechanize'
  gem 'timecop'
end
