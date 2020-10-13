class RefreshWithEmptyUrl < WEBrick::HTTPServlet::AbstractServlet
  @@count = 0
  def do_GET(req, res)
    address = "#{req.host}:#{req.port}"

    res.content_type = "text/html"
    @@count += 1
    if @@count > 1
      res['Refresh'] = "0; url=http://#{address}/";
    else
      res['Refresh'] = "0; url=";
    end
  end
end

