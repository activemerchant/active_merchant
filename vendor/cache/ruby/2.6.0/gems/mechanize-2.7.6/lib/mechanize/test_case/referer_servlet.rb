class RefererServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Content-Type'] = "text/html"
    res.body = req['Referer'] || ''
  end

  def do_POST(req, res)
    res['Content-Type'] = "text/html"
    res.body = req['Referer'] || ''
  end
end

