require 'webrick'
require 'mechanize/test_case/servlets'

server = WEBrick::HTTPServer.new :Port => 8000
server.mount_proc '/' do |req, res|
  res.content_type = 'text/html'

  servlets = MECHANIZE_TEST_CASE_SERVLETS.map do |path, servlet|
    "<dt>#{servlet}<dd><a href=\"#{path}\">#{path}</a>"
  end.join "\n"

  res.body = <<-BODY
<!DOCTYPE html>
<title>Mechanize Test Case Servlets</title>
<p>This server allows you to test various mechanize behavior against other
HTTP clients.  Some endpoints may require headers be set to have a reasonable
function, or may respond diffently to POST vs GET requests.  Please see the
servlet implementation and mechanize tests for further details.

<p>Here are the servlet endpoints available:

<dl>
#{servlets}
</dl>
  BODY
end

MECHANIZE_TEST_CASE_SERVLETS.each do |path, servlet|
  server.mount path, servlet
end

trap 'INT'  do server.shutdown end
trap 'TERM' do server.shutdown end

server.start

