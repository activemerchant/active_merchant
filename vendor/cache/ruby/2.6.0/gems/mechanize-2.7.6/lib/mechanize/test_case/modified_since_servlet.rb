class ModifiedSinceServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    s_time = 'Fri, 04 May 2001 00:00:38 GMT'

    my_time = Time.parse(s_time)

    if req['If-Modified-Since']
      your_time = Time.parse(req['If-Modified-Since'])
      if my_time > your_time
        res.body = 'This page was updated since you requested'
      else
        res.status = 304
      end
    else
      res.body = 'You did not send an If-Modified-Since header'
    end

    res['Last-Modified'] = s_time
  end
end

