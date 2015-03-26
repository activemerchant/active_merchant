source 'https://rubygems.org'
gemspec

gem 'builder', '~> 3.0'
gem 'activesupport', '~> 3.2'
gem 'rails', '~> 3.2'
gem 'pry'
gem 'jruby-openssl', :platforms => :jruby

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 2.0.0'
end
