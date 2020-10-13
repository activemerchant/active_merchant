class RedirectServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Content-Type'] = req.query['ct'] || 'text/html'
    res.status = req.query['code'] ? req.query['code'].to_i : '302'
    res['Location'] = req['X-Location'] || '/verb'
  end

  alias :do_POST :do_GET
  alias :do_HEAD :do_GET
  alias :do_PUT :do_GET
  alias :do_DELETE :do_GET
end

