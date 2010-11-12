$:.unshift File.expand_path('../lib', __FILE__)

require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'support/gateway_support'
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

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ActiveMerchant library"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main=README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/tasks')
end

desc "Delete tar.gz / zip / rdoc"
task :cleanup => [ :clobber_package, :clobber_rdoc ]

spec = eval(File.read('activemerchant.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
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
  
end