class BadChunkingServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET req, res
    res.keep_alive = false if res.respond_to? :keep_alive=

    res['Transfer-Encoding'] = 'chunked'

    res.body = <<-BODY
a\r
0123456789\r
0\r
    BODY
  end
end

