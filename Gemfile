source 'https://rubygems.org'
gemspec

gem 'jruby-openssl', platforms: :jruby
gem 'rubocop', '~> 0.62.0', require: false

gem 'rexml' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0')

group :test, :remote_test do
  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'braintree', '>= 3.0.0', '<= 3.0.1'
  gem 'jose', '~> 1.1.3'
  gem 'jwe'
  gem 'mechanize'
end
