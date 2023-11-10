source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', :platforms => :jruby
gem 'clientele', git: 'git@github.com:getaroom/clientele.git', branch: 'DEV-16429-rpoe-payment-capture'
gem 'open_travel',        git: 'git@github.com:getaroom/open_travel.git'

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 2.78.0'
end
