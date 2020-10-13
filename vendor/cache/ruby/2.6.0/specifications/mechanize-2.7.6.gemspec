# -*- encoding: utf-8 -*-
# stub: mechanize 2.7.6 ruby lib

Gem::Specification.new do |s|
  s.name = "mechanize".freeze
  s.version = "2.7.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Eric Hodel".freeze, "Aaron Patterson".freeze, "Mike Dalessio".freeze, "Akinori MUSHA".freeze, "Lee Jarvis".freeze]
  s.date = "2018-06-02"
  s.description = "The Mechanize library is used for automating interaction with websites.\nMechanize automatically stores and sends cookies, follows redirects,\nand can follow links and submit forms.  Form fields can be populated and\nsubmitted.  Mechanize also keeps track of the sites that you have visited as\na history.".freeze
  s.email = ["drbrain@segment7.net".freeze, "aaronp@rubyforge.org".freeze, "mike.dalessio@gmail.com".freeze, "knu@idaemons.org".freeze, "ljjarvis@gmail.com".freeze]
  s.extra_rdoc_files = ["EXAMPLES.rdoc".freeze, "CHANGELOG.rdoc".freeze, "GUIDE.rdoc".freeze, "LICENSE.rdoc".freeze, "README.rdoc".freeze]
  s.files = ["CHANGELOG.rdoc".freeze, "EXAMPLES.rdoc".freeze, "GUIDE.rdoc".freeze, "LICENSE.rdoc".freeze, "README.rdoc".freeze]
  s.homepage = "http://docs.seattlerb.org/mechanize/".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--main".freeze, "README.rdoc".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "The Mechanize library is used for automating interaction with websites".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<net-http-digest_auth>.freeze, [">= 1.1.1", "~> 1.1"])
      s.add_runtime_dependency(%q<mime-types>.freeze, [">= 1.17.2"])
      s.add_runtime_dependency(%q<net-http-persistent>.freeze, [">= 2.5.2"])
      s.add_runtime_dependency(%q<http-cookie>.freeze, ["~> 1.0"])
      s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
      s.add_runtime_dependency(%q<ntlm-http>.freeze, [">= 0.1.1", "~> 0.1"])
      s.add_runtime_dependency(%q<webrobots>.freeze, ["< 0.2", ">= 0.0.9"])
      s.add_runtime_dependency(%q<domain_name>.freeze, [">= 0.5.1", "~> 0.5"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.0"])
    else
      s.add_dependency(%q<net-http-digest_auth>.freeze, [">= 1.1.1", "~> 1.1"])
      s.add_dependency(%q<mime-types>.freeze, [">= 1.17.2"])
      s.add_dependency(%q<net-http-persistent>.freeze, [">= 2.5.2"])
      s.add_dependency(%q<http-cookie>.freeze, ["~> 1.0"])
      s.add_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
      s.add_dependency(%q<ntlm-http>.freeze, [">= 0.1.1", "~> 0.1"])
      s.add_dependency(%q<webrobots>.freeze, ["< 0.2", ">= 0.0.9"])
      s.add_dependency(%q<domain_name>.freeze, [">= 0.5.1", "~> 0.5"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.0"])
    end
  else
    s.add_dependency(%q<net-http-digest_auth>.freeze, [">= 1.1.1", "~> 1.1"])
    s.add_dependency(%q<mime-types>.freeze, [">= 1.17.2"])
    s.add_dependency(%q<net-http-persistent>.freeze, [">= 2.5.2"])
    s.add_dependency(%q<http-cookie>.freeze, ["~> 1.0"])
    s.add_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
    s.add_dependency(%q<ntlm-http>.freeze, [">= 0.1.1", "~> 0.1"])
    s.add_dependency(%q<webrobots>.freeze, ["< 0.2", ">= 0.0.9"])
    s.add_dependency(%q<domain_name>.freeze, [">= 0.5.1", "~> 0.5"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.0"])
  end
end
