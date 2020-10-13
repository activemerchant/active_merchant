class InfiniteRefreshServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    address = "#{req.host}:#{req.port}"
    res['Content-Type'] = req.query['ct'] || "text/html"
    res.status = req.query['code'] ? req.query['code'].to_i : '302'
    number = req.query['q'] ? req.query['q'].to_i : 0
    res['Refresh'] = "0;url=http://#{address}/infinite_refresh?q=#{number + 1}";
  end
end
