source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', :platforms => :jruby

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 2.50.0'
end

gem 'rails', github: 'rails/rails'
gem 'arel', github: 'rails/arel'
gem 'rack', github: 'rack/rack'
