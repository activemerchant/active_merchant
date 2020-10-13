require 'webrick'
require 'tempfile'

class AuthServlet < WEBrick::HTTPServlet::AbstractServlet

  @instance = nil

  def self.get_instance server, *options
    @instance ||= new(server, *options)
  end

  def initialize server
    super server

    config = {}
    config[:Realm] = 'net-http-digest_auth'
    config[:UseOpaque] = false
    config[:AutoReloadUserDB] = false

    passwd_file = Tempfile.new 'net-http-digest_auth'
    passwd_file.close

    htpasswd = WEBrick::HTTPAuth::Htpasswd.new passwd_file.path
    htpasswd.auth_type = WEBrick::HTTPAuth::DigestAuth
    htpasswd.set_passwd config[:Realm], 'username', 'password'
    htpasswd.flush

    config[:UserDB] = htpasswd

    @digest_auth = WEBrick::HTTPAuth::DigestAuth.new config
  end

  def do_GET req, res
    @digest_auth.authenticate req, res

    res.body = 'worked!'
  end

end

s = WEBrick::HTTPServer.new :Port => 8000
s.mount '/', AuthServlet

trap 'INT' do s.shutdown end

s.start

