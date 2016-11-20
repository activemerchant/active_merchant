source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', :platforms => :jruby
gem 'recurly', '~> 2.7.4'

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 2.50.0'
end
