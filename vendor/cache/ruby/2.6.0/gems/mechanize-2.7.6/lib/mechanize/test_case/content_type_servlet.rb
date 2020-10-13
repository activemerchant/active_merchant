class ContentTypeServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    ct = req.query['ct'] || "text/html; charset=utf-8"
    res['Content-Type'] = ct
    res.body = "Hello World"
  end
end

