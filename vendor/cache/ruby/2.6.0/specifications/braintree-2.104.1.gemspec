# -*- encoding: utf-8 -*-
# stub: braintree 2.104.1 ruby lib

Gem::Specification.new do |s|
  s.name = "braintree".freeze
  s.version = "2.104.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/braintree/braintree_ruby/issues", "changelog_uri" => "https://github.com/braintree/braintree_ruby/blob/master/CHANGELOG.md", "source_code_uri" => "https://github.com/braintree/braintree_ruby" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Braintree".freeze]
  s.date = "2020-10-12"
  s.description = "Ruby library for integrating with the Braintree Gateway".freeze
  s.email = "code@getbraintree.com".freeze
  s.homepage = "https://www.braintreepayments.com/".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Braintree Gateway Ruby Client Library".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<builder>.freeze, [">= 2.0.0"])
    else
      s.add_dependency(%q<builder>.freeze, [">= 2.0.0"])
    end
  else
    s.add_dependency(%q<builder>.freeze, [">= 2.0.0"])
  end
end
