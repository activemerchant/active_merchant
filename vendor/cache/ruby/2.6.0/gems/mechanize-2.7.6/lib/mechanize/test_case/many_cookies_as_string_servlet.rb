class ManyCookiesAsStringServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    cookies = []
    name_cookie = WEBrick::Cookie.new("name", "Aaron")
    name_cookie.path = "/"
    name_cookie.expires = Time.now + 86400
    name_cookie.domain = 'localhost'
    cookies << name_cookie
    cookies << name_cookie
    cookies << name_cookie
    cookies << "#{name_cookie}; HttpOnly"

    expired_cookie = WEBrick::Cookie.new("expired", "doh")
    expired_cookie.path = "/"
    expired_cookie.expires = Time.now - 86400
    cookies << expired_cookie

    different_path_cookie = WEBrick::Cookie.new("a_path", "some_path")
    different_path_cookie.path = "/some_path"
    different_path_cookie.expires = Time.now + 86400
    cookies << different_path_cookie

    no_path_cookie = WEBrick::Cookie.new("no_path", "no_path")
    no_path_cookie.expires = Time.now + 86400
    cookies << no_path_cookie

    no_exp_path_cookie = WEBrick::Cookie.new("no_expires", "nope")
    no_exp_path_cookie.path = "/"
    cookies << no_exp_path_cookie

    res['Set-Cookie'] = cookies.join(', ')

    res['Content-Type'] = "text/html"
    res.body = "<html><body>hello</body></html>"
  end
end

