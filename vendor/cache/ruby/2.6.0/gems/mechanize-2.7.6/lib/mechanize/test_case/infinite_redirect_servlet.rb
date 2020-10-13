class InfiniteRedirectServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Content-Type'] = req.query['ct'] || "text/html"
    res.status = req.query['code'] ? req.query['code'].to_i : '302'
    number = req.query['q'] ? req.query['q'].to_i : 0
    res['Location'] = "/infinite_redirect?q=#{number + 1}"
  end
  alias :do_POST :do_GET
end

