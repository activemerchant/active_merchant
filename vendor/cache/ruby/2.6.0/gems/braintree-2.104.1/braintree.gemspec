$:.push File.expand_path("../lib", __FILE__)
require 'braintree/version'

Gem::Specification.new do |s|
  s.name = "braintree"
  s.summary = "Braintree Gateway Ruby Client Library"
  s.description = "Ruby library for integrating with the Braintree Gateway"
  s.version = Braintree::Version::String
  s.license = "MIT"
  s.author = "Braintree"
  s.email = "code@getbraintree.com"
  s.homepage = "https://www.braintreepayments.com/"
  s.files = Dir.glob ["README.rdoc", "LICENSE", "lib/**/*.{rb,crt}", "spec/**/*", "*.gemspec"]
  s.add_dependency "builder", ">= 2.0.0"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/braintree/braintree_ruby/issues",
    "changelog_uri" => "https://github.com/braintree/braintree_ruby/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/braintree/braintree_ruby",
  }
end

