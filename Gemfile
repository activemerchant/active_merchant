source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', :platforms => :jruby
gem 'rubocop', '~> 0.57.2'

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '~> 2.78'
end
