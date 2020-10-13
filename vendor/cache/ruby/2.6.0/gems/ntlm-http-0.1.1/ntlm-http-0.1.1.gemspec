Gem::Specification.new do |s|
  s.name = %q{ntlm-http}
  s.version = "0.1.1"
  s.date = %q{20-05-2009}
  s.summary = %q{Ruby/NTLM HTTP library.}
  s.email = %q{kingsley@mindflowsolutions.com}
  s.homepage = %q{http://www.mindflowsolutions.net}
  s.rubyforge_project = %q{rubyntlm}
  s.description = %q{Ruby/NTLM HTTP provides NTLM authentication over http.}
  s.autorequire = %q{net/ntlm_http}
  s.has_rdoc = true
  s.authors = ["Kohei Kajimoto,Kingsley Hendrickse"]
  s.files = ["ntlm-http-0.1.1.gemspec", "Rakefile", "README", "lib/net/ntlm.rb", "lib/net/ntlm_http.rb", "test/function_test.rb", "examples/http.rb", "examples/imap.rb", "examples/smtp.rb"]
  s.rdoc_options = ["--main", "README"]
  s.extra_rdoc_files = ["README"]
end
