class HeaderServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res.content_type = "text/plain"

    req.query.each do |x,y|
      res[x] = y
    end

    req.each do |k, v|
      res.body << "#{k}|#{v}\n"
    end
  end
end

