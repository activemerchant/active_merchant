class HttpRefreshServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Content-Type'] = req.query['ct'] || "text/html"
    refresh_time = req.query['refresh_time'] || 0
    refresh_url = req.query['refresh_url'] || '/'
    res['Refresh'] = " #{refresh_time};url=#{refresh_url}";
  end
end
