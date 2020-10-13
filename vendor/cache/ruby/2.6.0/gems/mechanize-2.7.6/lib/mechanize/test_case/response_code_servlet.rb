class ResponseCodeServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Content-Type'] = req.query['ct'] || "text/html"
    if req.query['code']
      code = req.query['code'].to_i
      case code
      when 300, 301, 302, 303, 304, 305, 307
        res['Location'] = "/index.html"
      end
      res.status = code
    else
    end
  end
end

