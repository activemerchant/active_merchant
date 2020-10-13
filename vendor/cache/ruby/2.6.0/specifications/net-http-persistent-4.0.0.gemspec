# -*- encoding: utf-8 -*-
# stub: net-http-persistent 4.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "net-http-persistent".freeze
  s.version = "4.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/drbrain/net-http-persistent" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Eric Hodel".freeze]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIDNjCCAh6gAwIBAgIBBzANBgkqhkiG9w0BAQsFADBBMRAwDgYDVQQDDAdkcmJy\nYWluMRgwFgYKCZImiZPyLGQBGRYIc2VnbWVudDcxEzARBgoJkiaJk/IsZAEZFgNu\nZXQwHhcNMjAwNDE0MDQxNjM0WhcNMjEwNDE0MDQxNjM0WjBBMRAwDgYDVQQDDAdk\ncmJyYWluMRgwFgYKCZImiZPyLGQBGRYIc2VnbWVudDcxEzARBgoJkiaJk/IsZAEZ\nFgNuZXQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCbbgLrGLGIDE76\nLV/cvxdEzCuYuS3oG9PrSZnuDweySUfdp/so0cDq+j8bqy6OzZSw07gdjwFMSd6J\nU5ddZCVywn5nnAQ+Ui7jMW54CYt5/H6f2US6U0hQOjJR6cpfiymgxGdfyTiVcvTm\nGj/okWrQl0NjYOYBpDi+9PPmaH2RmLJu0dB/NylsDnW5j6yN1BEI8MfJRR+HRKZY\nmUtgzBwF1V4KIZQ8EuL6I/nHVu07i6IkrpAgxpXUfdJQJi0oZAqXurAV3yTxkFwd\ng62YrrW26mDe+pZBzR6bpLE+PmXCzz7UxUq3AE0gPHbiMXie3EFE0oxnsU3lIduh\nsCANiQ8BAgMBAAGjOTA3MAkGA1UdEwQCMAAwCwYDVR0PBAQDAgSwMB0GA1UdDgQW\nBBS5k4Z75VSpdM0AclG2UvzFA/VW5DANBgkqhkiG9w0BAQsFAAOCAQEAcrJao+AD\nqFvUtuvzimPGJS1rtKJEvEvDTzEOnd4e+R+mVitEBp3AI8R4OZGf1wnPy7jYYtiL\nS8FhRBZRyXaQcvcL75eKicfIy8gPSg8d8YTs12BhXrF+ziTR6JJUB3DLkFjE3O84\nAid+DdQFk1ERR/GvpA9wQcax8DXzc9ONoN/kGdruXLtXSEwmOGJgmSV9iKK2Ot+x\n6A1NLSPq5zcsOzbmsaWlZphKnvH6oPqOLzMxwGJOz07/XXxICSYIccrWXdHZ3PPm\nUpBFtcBdupJTrY8t+BLoVN4zTlNqoDciUJBjHfem/2CiMy6oDqthQva1Kn8fquIf\nBHDiQW5MD5FN1g==\n-----END CERTIFICATE-----\n".freeze]
  s.date = "2020-05-01"
  s.description = "Manages persistent connections using Net::HTTP including a thread pool for\nconnecting to multiple hosts.\n\nUsing persistent HTTP connections can dramatically increase the speed of HTTP.\nCreating a new HTTP connection for every request involves an extra TCP\nround-trip and causes TCP congestion avoidance negotiation to start over.\n\nNet::HTTP supports persistent connections with some API methods but does not\nmake setting up a single persistent connection or managing multiple\nconnections easy.  Net::HTTP::Persistent wraps Net::HTTP and allows you to\nfocus on how to make HTTP requests.".freeze
  s.email = ["drbrain@segment7.net".freeze]
  s.extra_rdoc_files = ["History.txt".freeze, "Manifest.txt".freeze, "README.rdoc".freeze]
  s.files = ["History.txt".freeze, "Manifest.txt".freeze, "README.rdoc".freeze]
  s.homepage = "https://github.com/drbrain/net-http-persistent".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--main".freeze, "README.rdoc".freeze]
  s.required_ruby_version = Gem::Requirement.new("~> 2.3".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Manages persistent connections using Net::HTTP including a thread pool for connecting to multiple hosts".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<connection_pool>.freeze, ["~> 2.2"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.14"])
      s.add_development_dependency(%q<hoe-bundler>.freeze, ["~> 1.5"])
      s.add_development_dependency(%q<hoe-travis>.freeze, ["~> 1.4", ">= 1.4.1"])
      s.add_development_dependency(%q<rdoc>.freeze, [">= 4.0", "< 7"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.22"])
    else
      s.add_dependency(%q<connection_pool>.freeze, ["~> 2.2"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.14"])
      s.add_dependency(%q<hoe-bundler>.freeze, ["~> 1.5"])
      s.add_dependency(%q<hoe-travis>.freeze, ["~> 1.4", ">= 1.4.1"])
      s.add_dependency(%q<rdoc>.freeze, [">= 4.0", "< 7"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.22"])
    end
  else
    s.add_dependency(%q<connection_pool>.freeze, ["~> 2.2"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.14"])
    s.add_dependency(%q<hoe-bundler>.freeze, ["~> 1.5"])
    s.add_dependency(%q<hoe-travis>.freeze, ["~> 1.4", ">= 1.4.1"])
    s.add_dependency(%q<rdoc>.freeze, [">= 4.0", "< 7"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.22"])
  end
end
