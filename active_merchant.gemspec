# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_merchant/version"
require 'bundler'

Gem::Specification.new do |s|
  s.name        = "active_merchant"
  s.version     = ActiveMerchant::VERSION
  s.platform    = Gem::Platform::RUBY

  s.author      = 'Tobias Luetke'
  s.email       = 'tobi@leetsoft.com'
  s.homepage    = 'http://activemerchant.org/'
  s.date        = "2011-05-29"

  s.summary      = 'Framework and tools for dealing with credit card transactions.'
  s.description  = 'Active Merchant is a simple payment abstraction library used in and sponsored by Shopify. It is written by Tobias Luetke, Cody Fauser, and contributors. The aim of the project is to feel natural to Ruby users and to abstract as many parts as possible away from the user to offer a consistent interface across all supported gateways.'
  s.rubyforge_project = 'active_merchant'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.has_rdoc = true if Gem::VERSION < '1.7.0'

  s.add_dependency('activesupport', '>= 2.3.11')
  s.add_dependency('money')
  s.add_dependency('braintree', '>= 2.0.0')
  s.add_dependency('rdoc')

  s.add_development_dependency('rails', '>= 2.3.11')
  s.add_development_dependency('i18n')
  s.add_development_dependency('mocha')
  s.add_development_dependency('rake')

  #Remote test requirements
  s.add_development_dependency('mechanize')
  s.add_development_dependency('launchy')
  s.add_development_dependency('mongrel')

  s.signing_key = ENV['GEM_PRIVATE_KEY']
  s.cert_chain  = ['gem-public_cert.pem']

end