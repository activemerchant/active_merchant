class RefreshWithoutUrl < WEBrick::HTTPServlet::AbstractServlet
  @@count = 0
  def do_GET(req, res)
    address = "#{req.host}:#{req.port}"
    res['Content-Type'] = "text/html"
    @@count += 1
    if @@count > 1
      res['Refresh'] = "0; url=http://#{address}/";
    else
      res['Refresh'] = "0";
    end
  end
end

