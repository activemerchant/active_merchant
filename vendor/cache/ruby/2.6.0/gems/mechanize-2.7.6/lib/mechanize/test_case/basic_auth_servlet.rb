class BasicAuthServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req,res)
    htpd = nil
    Tempfile.open 'dot.htpasswd' do |io|
      htpd = WEBrick::HTTPAuth::Htpasswd.new(io.path)
      htpd.set_passwd('Blah', 'user', 'pass')
    end

    authenticator = WEBrick::HTTPAuth::BasicAuth.new({
      :UserDB => htpd,
      :Realm  => 'Blah',
      :Logger => Logger.new(nil)
    })

    begin
      authenticator.authenticate(req,res)
      res.body = 'You are authenticated'
    rescue WEBrick::HTTPStatus::Unauthorized
      res.status = 401
    end
  end
  alias :do_POST :do_GET
end

