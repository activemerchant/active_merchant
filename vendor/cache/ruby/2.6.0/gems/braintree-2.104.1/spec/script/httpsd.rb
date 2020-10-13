#!/usr/bin/env ruby
require 'webrick'
require 'webrick/https'
require 'openssl'

private_key_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "ssl", "privateKey.key"))
cert_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "ssl", "certificate.crt"))

pkey = OpenSSL::PKey::RSA.new(File.read(private_key_file))
cert = OpenSSL::X509::Certificate.new(File.read(cert_file))

pid_file = ARGV[0]

s = WEBrick::HTTPServer.new(
  :Port => (ENV['SSL_TEST_PORT'] || 8444),
  :Logger => WEBrick::Log::new(nil, WEBrick::Log::ERROR),
  :DocumentRoot => File.join(File.dirname(__FILE__)),
  :ServerType => WEBrick::Daemon,
  :SSLEnable => true,
  :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
  :SSLCertificate => cert,
  :SSLPrivateKey => pkey,
  :SSLCertName => [ [ "CN",WEBrick::Utils::getservername ] ],
  :StartCallback => proc { File.open(pid_file, "w") { |f| f.write $$.to_s }}
)
trap("INT"){ s.shutdown }
s.start
