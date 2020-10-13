class SendCookiesServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res.content_type = 'text/html'

    cookies = req.cookies.map do |c|
      "<li><a href=\"#\">#{c.name}:#{c.value}</a>"
    end.join "\n"

    res.body = <<-BODY
<!DOCTYPE html>
<title>Your cookies</title>

<ul>
#{cookies}
</ul>
    BODY
  end
end

