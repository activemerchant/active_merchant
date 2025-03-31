source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', platforms: :jruby
gem 'rubocop', '~> 1.26.0', require: false

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 4.26.0'
  gem 'concurrent-ruby', '1.3.4'
  gem 'jose', '~> 1.2.0'
  gem 'jwe'
  gem 'mechanize'
  gem 'timecop'
end
