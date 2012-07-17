$:.unshift File.expand_path('../lib', __FILE__)

begin
  require 'bundler'
  Bundler.setup
rescue LoadError => e
  puts "Error loading bundler (#{e.message}): \"gem install bundler\" for bundler support."
  require 'rubygems'
end

require 'rake'
require 'rake/testtask'
require 'rubygems/package_task'
require 'support/gateway_support'
require 'support/ssl_verify' 
require 'support/outbound_hosts'

desc "Run the unit test suite"
task :default => 'test:units'

namespace :test do

  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end

end

desc "Delete tar.gz / zip"
task :cleanup => [ :clobber_package ]

spec = eval(File.read('activemerchant.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

desc "Release the gems and docs to RubyForge"
task :release => [ 'gemcutter:publish' ]

namespace :gemcutter do
  desc "Publish to gemcutter"
  task :publish => :package do
    sh "gem push pkg/activemerchant-#{ActiveMerchant::VERSION}.gem"
  end
end

namespace :gateways do
  desc 'Print the currently supported gateways'
  task :print do
    support = GatewaySupport.new
    support.to_s
  end
  
  namespace :print do
    desc 'Print the currently supported gateways in RDoc format'
    task :rdoc do
      support = GatewaySupport.new
      support.to_rdoc
    end
  
    desc 'Print the currently supported gateways in Textile format'
    task :textile do
      support = GatewaySupport.new
      support.to_textile
    end
    
    desc 'Print the gateway functionality supported by each gateway'
    task :features do
      support = GatewaySupport.new
      support.features
    end
  end
  
  desc 'Print the list of destination hosts with port'
  task :hosts do
    OutboundHosts.list
  end
 
  desc 'Test that gateways allow SSL verify_peer'
  task :ssl_verify do
    SSLVerify.new.test_gateways
  end 
end
