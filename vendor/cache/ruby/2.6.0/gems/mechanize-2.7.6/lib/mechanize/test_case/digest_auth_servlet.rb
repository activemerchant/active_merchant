require 'logger'

class DigestAuthServlet < WEBrick::HTTPServlet::AbstractServlet
  htpd = nil

  Tempfile.open 'digest.htpasswd' do |io|
    htpd = WEBrick::HTTPAuth::Htdigest.new(io.path)
    htpd.set_passwd('Blah', 'user', 'pass')
  end

  @@authenticator = WEBrick::HTTPAuth::DigestAuth.new({
    :UserDB => htpd,
    :Realm  => 'Blah',
    :Algorithm => 'MD5',
    :Logger => Logger.new(nil)
  })

  def do_GET req, res
    def req.request_time; Time.now; end
    def req.request_uri; '/digest_auth'; end
    def req.request_method; 'GET'; end

    begin
      @@authenticator.authenticate req, res
      res.body = 'You are authenticated'
    rescue WEBrick::HTTPStatus::Unauthorized
      res.status = 401
    end
  end

  alias :do_POST :do_GET
end

