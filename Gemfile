source :rubygems
gemspec

group :test do
  gem 'json-jruby', :platforms => :jruby
  gem 'jruby-openssl', :platforms => :jruby

  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'samurai', '>= 0.2.25'
end

group :remote_test do
  gem 'mechanize'
  gem 'launchy'
  gem 'mongrel', '1.2.0.pre2', :platforms => :ruby

  # gateway-specific dependencies, keeping these gems out of the gemspec
  gem 'samurai', '>= 0.2.25'
end

