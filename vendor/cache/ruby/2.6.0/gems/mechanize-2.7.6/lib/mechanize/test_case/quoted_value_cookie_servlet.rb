class QuotedValueCookieServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    cookie = WEBrick::Cookie.new("quoted", "\"value\"")
    cookie.path = "/"
    cookie.expires = Time.now + 86400
    res.cookies << cookie
    res['Content-Type'] = "text/html"
    res.body = "<html><body>hello</body></html>"
  end
end

