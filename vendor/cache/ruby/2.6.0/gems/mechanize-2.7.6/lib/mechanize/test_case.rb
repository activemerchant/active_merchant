require 'mechanize'
require 'logger'
require 'tempfile'
require 'tmpdir'
require 'webrick'
require 'zlib'

require 'rubygems'

begin
  gem 'minitest'
rescue Gem::LoadError
end

require 'minitest/autorun'

begin
  require 'minitest/pride'
rescue LoadError
end

##
# A generic test case for testing mechanize.  Using a subclass of
# Mechanize::TestCase for your tests will create an isolated mechanize
# instance that won't pollute your filesystem or other tests.
#
# Once Mechanize::TestCase is loaded no HTTP requests will be made outside
# mechanize itself.  All requests are handled via WEBrick servlets.
#
# Mechanize uses WEBrick servlets to test some functionality.  You can run
# other HTTP clients against the servlets using:
#
#   ruby -rmechanize/test_case/server -e0
#
# Which will launch a test server at http://localhost:8000

class Mechanize::TestCase < Minitest::Test

  TEST_DIR = File.expand_path '../../../test', __FILE__
  REQUESTS = []

  ##
  # Creates a clean mechanize instance +@mech+ for use in tests.

  def setup
    super

    REQUESTS.clear
    @mech = Mechanize.new
    @ssl_private_key = nil
    @ssl_certificate = nil
  end

  ##
  # Creates a fake page with URI http://fake.example and an empty, submittable
  # form.

  def fake_page agent = @mech
    uri = URI 'http://fake.example/'
    html = <<-END
<html>
<body>
<form><input type="submit" value="submit" /></form>
</body>
</html>
    END

    Mechanize::Page.new uri, nil, html, 200, agent
  end

  ##
  # Is the Encoding constant defined?

  def have_encoding?
    Object.const_defined? :Encoding
  end

  ##
  # Creates a Mechanize::Page with the given +body+

  def html_page body
    uri = URI 'http://example/'
    Mechanize::Page.new uri, nil, body, 200, @mech
  end

  ##
  # Creates a Mechanize::CookieJar by parsing the given +str+

  def cookie_jar str, uri = URI('http://example')
    jar = Mechanize::CookieJar.new

    jar.parse str, uri

    jar
  end

  ##
  # Runs the block inside a temporary directory

  def in_tmpdir
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        yield
      end
    end
  end

  ##
  # Creates a Nokogiri Node +element+ with the given +attributes+

  def node element, attributes = {}
    doc = Nokogiri::HTML::Document.new

    node = Nokogiri::XML::Node.new element, doc

    attributes.each do |name, value|
      node[name] = value
    end

    node
  end

  ##
  # Creates a Mechanize::Page for the given +uri+ with the given
  # +content_type+, response +body+ and HTTP status +code+

  def page uri, content_type = 'text/html', body = '', code = 200
    uri = URI uri unless URI::Generic === uri

    Mechanize::Page.new(uri, { 'content-type' => content_type }, body, code,
                        @mech)
  end

  ##
  # Requests made during this tests

  def requests
    REQUESTS
  end

  ##
  # An SSL private key.  This key is the same across all test runs

  def ssl_private_key
    @ssl_private_key ||= OpenSSL::PKey::RSA.new <<-KEY
-----BEGIN RSA PRIVATE KEY-----
MIG7AgEAAkEA8pmEfmP0Ibir91x6pbts4JmmsVZd3xvD5p347EFvBCbhBW1nv1Gs
bCBEFlSiT1q2qvxGb5IlbrfdhdgyqdTXUQIBAQIBAQIhAPumXslvf6YasXa1hni3
p80joKOug2UUgqOLD2GUSO//AiEA9ssY6AFxjHWuwo/+/rkLmkfO2s1Lz3OeUEWq
6DiHOK8CAQECAQECIQDt8bc4vS6wh9VXApNSKIpVygtxSFe/IwLeX26n77j6Qg==
-----END RSA PRIVATE KEY-----
    KEY
  end

  ##
  # An X509 certificate.  This certificate is the same across all test runs

  def ssl_certificate
    @ssl_certificate ||= OpenSSL::X509::Certificate.new <<-CERT
-----BEGIN CERTIFICATE-----
MIIBQjCB7aADAgECAgEAMA0GCSqGSIb3DQEBBQUAMCoxDzANBgNVBAMMBm5vYm9k
eTEXMBUGCgmSJomT8ixkARkWB2V4YW1wbGUwIBcNMTExMTAzMjEwODU5WhgPOTk5
OTEyMzExMjU5NTlaMCoxDzANBgNVBAMMBm5vYm9keTEXMBUGCgmSJomT8ixkARkW
B2V4YW1wbGUwWjANBgkqhkiG9w0BAQEFAANJADBGAkEA8pmEfmP0Ibir91x6pbts
4JmmsVZd3xvD5p347EFvBCbhBW1nv1GsbCBEFlSiT1q2qvxGb5IlbrfdhdgyqdTX
UQIBATANBgkqhkiG9w0BAQUFAANBAAAB////////////////////////////////
//8AMCEwCQYFKw4DAhoFAAQUePiv+QrJxyjtEJNnH5pB9OTWIqA=
-----END CERTIFICATE-----
    CERT
  end

  ##
  # Creates a Tempfile with +content+ that is immediately unlinked

  def tempfile content
    body_io = Tempfile.new @NAME
    body_io.unlink
    body_io.write content
    body_io.flush
    body_io.rewind

    body_io
  end

end

require 'mechanize/test_case/servlets'

module Net # :nodoc:
end

class Net::HTTP # :nodoc:
  alias :old_do_start :do_start

  def do_start
    @started = true
  end

  PAGE_CACHE = {}

  alias :old_request :request

  def request(req, *data, &block)
    url = URI.parse(req.path)
    path = WEBrick::HTTPUtils.unescape(url.path)

    path = '/index.html' if path == '/'

    res = ::Response.new
    res.query_params = url.query

    req.query = if 'POST' != req.method && url.query then
                  WEBrick::HTTPUtils.parse_query url.query
                elsif req['content-type'] =~ /www-form-urlencoded/ then
                  WEBrick::HTTPUtils.parse_query req.body
                elsif req['content-type'] =~ /boundary=(.+)/ then
                  boundary = WEBrick::HTTPUtils.dequote $1
                  WEBrick::HTTPUtils.parse_form_data req.body, boundary
                else
                  {}
                end

    req.cookies = WEBrick::Cookie.parse(req['Cookie'])

    Mechanize::TestCase::REQUESTS << req

    if servlet_klass = MECHANIZE_TEST_CASE_SERVLETS[path]
      servlet = servlet_klass.new({})
      servlet.send "do_#{req.method}", req, res
    else
      filename = "htdocs#{path.gsub(/[^\/\\.\w\s]/, '_')}"
      unless PAGE_CACHE[filename]
        open("#{Mechanize::TestCase::TEST_DIR}/#{filename}", 'rb') { |io|
          PAGE_CACHE[filename] = io.read
        }
      end

      res.body = PAGE_CACHE[filename]
      case filename
      when /\.txt$/
        res['Content-Type'] = 'text/plain'
      when /\.jpg$/
        res['Content-Type'] = 'image/jpeg'
      end
    end

    res['Content-Type'] ||= 'text/html'
    res.code ||= "200"

    response_klass = Net::HTTPResponse::CODE_TO_OBJ[res.code.to_s]
    response = response_klass.new res.http_version, res.code, res.message

    res.header.each do |k,v|
      v = v.first if v.length == 1
      response[k] = v
    end

    res.cookies.each do |cookie|
      response.add_field 'Set-Cookie', cookie.to_s
    end

    response['Content-Type'] ||= 'text/html'
    response['Content-Length'] = res['Content-Length'] || res.body.length.to_s

    io = StringIO.new(res.body)
    response.instance_variable_set :@socket, io
    def io.read clen, dest = nil, _ = nil
      if dest then
        dest << super(clen)
      else
        super clen
      end
    end

    body_exist = req.response_body_permitted? &&
      response_klass.body_permitted?

    response.instance_variable_set :@body_exist, body_exist

    yield response if block_given?

    response
  end
end

class Net::HTTPRequest # :nodoc:
  attr_accessor :query, :body, :cookies, :user

  def host
    'example'
  end

  def port
    80
  end
end

class Response # :nodoc:
  include Net::HTTPHeader

  attr_reader :code
  attr_accessor :body, :query, :cookies
  attr_accessor :query_params, :http_version
  attr_accessor :header

  def code=(c)
    @code = c.to_s
  end

  alias :status :code
  alias :status= :code=

    def initialize
      @header = {}
      @body = ''
      @code = nil
      @query = nil
      @cookies = []
      @http_version = '1.1'
    end

  def read_body
    yield body
  end

  def message
    ''
  end
end

