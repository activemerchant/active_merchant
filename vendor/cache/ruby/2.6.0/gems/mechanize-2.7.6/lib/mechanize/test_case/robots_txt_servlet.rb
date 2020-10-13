class RobotsTxtServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    if /301/ === req['Host'] && req.path == '/robots.txt'
      res['Location'] = 'http://301/robots_txt'
      res.code = 301
    else
      res['Content-Type'] = 'text/plain'
      res.body = <<-'EOF'
User-Agent: *
Disallow: /norobots
      EOF
    end
  end
end
