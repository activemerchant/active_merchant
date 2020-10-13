# -*- encoding: utf-8 -*-
# stub: webrobots 0.1.2 ruby lib

Gem::Specification.new do |s|
  s.name = "webrobots".freeze
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Akinori MUSHA".freeze]
  s.date = "2016-01-04"
  s.description = "This library helps write robots.txt compliant web robots in Ruby.\n".freeze
  s.email = ["knu@idaemons.org".freeze]
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "README.rdoc".freeze]
  s.files = ["LICENSE.txt".freeze, "README.rdoc".freeze]
  s.homepage = "https://github.com/knu/webrobots".freeze
  s.licenses = ["2-clause BSDL".freeze]
  s.rdoc_options = ["--exclude".freeze, "\\.ry$".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "A Ruby library to help write robots.txt compliant web robots".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>.freeze, [">= 0.9.2.2"])
      s.add_development_dependency(%q<racc>.freeze, [">= 0"])
      s.add_development_dependency(%q<test-unit>.freeze, [">= 0"])
      s.add_development_dependency(%q<shoulda>.freeze, [">= 0"])
      s.add_development_dependency(%q<webmock>.freeze, [">= 0"])
      s.add_development_dependency(%q<vcr>.freeze, [">= 0"])
      s.add_development_dependency(%q<rdoc>.freeze, ["> 2.4.2"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.2", ">= 1.2"])
      s.add_development_dependency(%q<nokogiri>.freeze, [">= 1.4.7", "~> 1.4"])
      s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
      s.add_development_dependency(%q<coveralls>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rake>.freeze, [">= 0.9.2.2"])
      s.add_dependency(%q<racc>.freeze, [">= 0"])
      s.add_dependency(%q<test-unit>.freeze, [">= 0"])
      s.add_dependency(%q<shoulda>.freeze, [">= 0"])
      s.add_dependency(%q<webmock>.freeze, [">= 0"])
      s.add_dependency(%q<vcr>.freeze, [">= 0"])
      s.add_dependency(%q<rdoc>.freeze, ["> 2.4.2"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.2", ">= 1.2"])
      s.add_dependency(%q<nokogiri>.freeze, [">= 1.4.7", "~> 1.4"])
      s.add_dependency(%q<simplecov>.freeze, [">= 0"])
      s.add_dependency(%q<coveralls>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rake>.freeze, [">= 0.9.2.2"])
    s.add_dependency(%q<racc>.freeze, [">= 0"])
    s.add_dependency(%q<test-unit>.freeze, [">= 0"])
    s.add_dependency(%q<shoulda>.freeze, [">= 0"])
    s.add_dependency(%q<webmock>.freeze, [">= 0"])
    s.add_dependency(%q<vcr>.freeze, [">= 0"])
    s.add_dependency(%q<rdoc>.freeze, ["> 2.4.2"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.2", ">= 1.2"])
    s.add_dependency(%q<nokogiri>.freeze, [">= 1.4.7", "~> 1.4"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<coveralls>.freeze, [">= 0"])
  end
end
