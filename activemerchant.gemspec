Gem::Specification.new do |s|
  s.platform     = Gem::Platform::RUBY
  s.name         = 'activemerchant'
  s.version      = '1.12.1'
  s.summary      = 'Framework and tools for dealing with credit card transactions.'
  s.description  = 'Active Merchant is a simple payment abstraction library used in and sponsored by Shopify. It is written by Tobias Luetke, Cody Fauser, and contributors. The aim of the project is to feel natural to Ruby users and to abstract as many parts as possible away from the user to offer a consistent interface across all supported gateways.'

  s.author = 'Tobias Luetke'
  s.email = 'tobi@leetsoft.com'
  s.homepage = 'http://activemerchant.org/'
  s.rubyforge_project = 'activemerchant'
  
  s.files = Dir['CHANGELOG', 'README.rdoc', 'MIT-LICENSE', 'CONTRIBUTORS', 'gem-public_cert.pem', 'lib/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  
  s.has_rdoc = true
  
  s.add_dependency('activesupport', '>= 2.3.8')
  s.add_dependency('builder', '>= 2.0.0')
  s.add_dependency('braintree', '>= 2.0.0')
  
  s.signing_key = ENV['GEM_PRIVATE_KEY']
  s.cert_chain  = ['gem-public_cert.pem']
end
