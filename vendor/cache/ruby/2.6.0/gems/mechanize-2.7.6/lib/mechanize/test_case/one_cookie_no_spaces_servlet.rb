class OneCookieNoSpacesServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    cookie = WEBrick::Cookie.new("foo", "bar")
    cookie.path = "/"
    cookie.expires = Time.now + 86400
    res.cookies << cookie.to_s.gsub(/; /, ';')
    res['Content-Type'] = "text/html"
    res.body = "<html><body>hello</body></html>"
  end
end

