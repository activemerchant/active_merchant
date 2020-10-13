# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mechanize/version'

Gem::Specification.new do |spec|
  spec.name          = "mechanize"
  spec.version       = Mechanize::VERSION
  spec.homepage      = "http://docs.seattlerb.org/mechanize/"
  spec.summary       = %q{The Mechanize library is used for automating interaction with websites}
  spec.description   =
    [
      "The Mechanize library is used for automating interaction with websites.",
      "Mechanize automatically stores and sends cookies, follows redirects,",
      "and can follow links and submit forms.  Form fields can be populated and",
      "submitted.  Mechanize also keeps track of the sites that you have visited as",
      "a history."
    ].join("\n")

  spec.authors =
    [
      'Eric Hodel',
      'Aaron Patterson',
      'Mike Dalessio',
      'Akinori MUSHA',
      'Lee Jarvis'
    ]
  spec.email =
    [
      'drbrain@segment7.net',
      'aaronp@rubyforge.org',
      'mike.dalessio@gmail.com',
      'knu@idaemons.org',
      'ljjarvis@gmail.com'
    ]

  spec.license           = "MIT"

  spec.require_paths = ["lib"]
  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^test/})

  spec.extra_rdoc_files += Dir['*.rdoc']
  spec.rdoc_options     = ["--main", "README.rdoc"]

  spec.required_ruby_version = ">= 1.9.2"

  spec.add_runtime_dependency "net-http-digest_auth", [ ">= 1.1.1", "~> 1.1" ]
  if RUBY_VERSION >= "2.0"
    spec.add_runtime_dependency "mime-types", [ ">= 1.17.2" ]
    spec.add_runtime_dependency "net-http-persistent", [ ">= 2.5.2"]
  else
    spec.add_runtime_dependency "mime-types", [ ">= 1.17.2", "< 3" ]
    spec.add_runtime_dependency "net-http-persistent", [ ">= 2.5.2", "~> 2.5" ]
  end
  spec.add_runtime_dependency "http-cookie",          [ "~> 1.0" ]
  spec.add_runtime_dependency "nokogiri",             [ "~> 1.6" ]
  spec.add_runtime_dependency "ntlm-http",            [ ">= 0.1.1", "~> 0.1"   ]
  spec.add_runtime_dependency "webrobots",            [ "< 0.2",    ">= 0.0.9" ]
  spec.add_runtime_dependency "domain_name",          [ ">= 0.5.1", "~> 0.5"   ]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "bundler",  "~> 1.3"
  spec.add_development_dependency "rdoc",     "~> 4.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
