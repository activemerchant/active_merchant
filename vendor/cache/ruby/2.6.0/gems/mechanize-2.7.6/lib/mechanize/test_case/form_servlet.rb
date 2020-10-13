class FormServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res.content_type = 'text/html'

    query = []

    req.query.each_key { |k|
      key = WEBrick::HTTPUtils.unescape k

      req.query[k].each_data { |data|
        value = WEBrick::HTTPUtils.unescape data
        query << "<li><a href=\"#\">#{key}:#{value}</a>"
      }
    }

    res.body = <<-BODY
<!DOCTYPE html>
<title>GET results</title>

<ul>
#{query.join "\n"}
</ul>

<div id=\"query\">#{req.query}</div>
    BODY
  end

  def do_POST(req, res)
    res.content_type = 'text/html'

    query = []

    req.query.each_key { |k|
      key = WEBrick::HTTPUtils.unescape k

      req.query[k].each_data { |data|
        value = WEBrick::HTTPUtils.unescape data
        query << "<li><a href=\"#\">#{key}:#{value}</a>"
      }
    }

    res.body = <<-BODY
<!DOCTYPE html>
<title>POST results</title>

<ul>
#{query.join "\n"}
</ul>

<div id=\"query\">#{req.body}</div>
    BODY
  end

end

