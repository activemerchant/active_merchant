source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', :platforms => :jruby

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 2.98.0'
  gem 'mechanize'
end

source "https://rubygems.pkg.github.com/paywith" do
  gem "security_tools", "~> 1.0.4"
end
