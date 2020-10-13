# coding: utf-8

require 'mechanize/test_case'

class TestMechanizeHttpAgent < Mechanize::TestCase

  def setup
    super

    @agent = @mech.agent

    @uri = URI.parse 'http://example/'

    @req = Net::HTTP::Get.new '/'
    @res = Net::HTTPOK.allocate
    @res.instance_variable_set :@code, 200
    @res.instance_variable_set :@header, {}

    @headers = if RUBY_VERSION >= '2.0.0' then
                 %w[accept accept-encoding user-agent]
               else
                 %w[accept user-agent]
               end
  end

  def auth_realm uri, scheme, type
    base_uri = uri + '/'
    realm = Mechanize::HTTP::AuthRealm.new scheme, base_uri, 'r'
    @agent.authenticate_methods[base_uri][type] << realm

    realm
  end

  def jruby_zlib?
    if RUBY_ENGINE == 'jruby'
      meth = caller[0][/`(\w+)/, 1]
      warn "#{meth}: skipped because how Zlib handles error is different in JRuby"
      true
    else
      false
    end
  end

  def test_agent_is_named
    assert_equal 'mechanize', Mechanize::HTTP::Agent.new.http.name
    assert_equal 'unique', Mechanize::HTTP::Agent.new('unique').http.name
  end

  def test_auto_io
    Tempfile.open 'input' do |input_io|
      input_io.binmode
      input_io.write '12345'
      input_io.rewind

      out_io = @agent.auto_io @NAME, 1024, input_io

      assert_equal '12345', out_io.string

      assert_equal Encoding::BINARY, out_io.string.encoding if
        Object.const_defined? :Encoding
    end
  end

  def test_auto_io_chunk
    Tempfile.open 'input' do |input_io|
      chunks = []

      input_io.binmode
      input_io.write '12345'
      input_io.rewind

      @agent.auto_io @NAME, 1, input_io do |chunk|
        chunks << chunk
      end

      assert_equal %w[1 2 3 4 5], chunks
    end
  end

  def test_auto_io_tempfile
    @agent.max_file_buffer = 3

    Tempfile.open 'input' do |input_io|
      input_io.binmode
      input_io.write '12345'
      input_io.rewind

      out_io = @agent.auto_io @NAME, 1, input_io

      result = out_io.read
      assert_equal '12345', result

      assert_equal Encoding::BINARY, result.encoding if
        Object.const_defined? :Encoding
    end
  end

  def test_auto_io_yield
    Tempfile.open 'input' do |input_io|
      input_io.binmode
      input_io.write '12345'
      input_io.rewind

      out_io = @agent.auto_io @NAME, 1024, input_io do |chunk|
        "x#{chunk}"
      end

      assert_equal 'x12345', out_io.string
    end
  end

  def test_certificate_equals
    cert_path = File.expand_path '../data/server.crt', __FILE__
    cert = OpenSSL::X509::Certificate.new File.read cert_path

    @agent.certificate = cert

    assert_equal cert.to_pem, @agent.certificate.to_pem
  end

  def test_certificate_equals_file
    cert_path = File.expand_path '../data/server.crt', __FILE__

    cert = OpenSSL::X509::Certificate.new File.read cert_path

    @agent.certificate = cert_path

    assert_equal cert.to_pem, @agent.certificate.to_pem
  end

  def test_connection_for_file
    uri = URI.parse 'file:///nonexistent'
    conn = @agent.connection_for uri

    assert_equal Mechanize::FileConnection.new, conn
  end

  def test_connection_for_http
    conn = @agent.connection_for @uri

    assert_equal @agent.http, conn
  end

  def test_disable_keep_alive
    @agent.disable_keep_alive @req

    refute @req['connection']
  end

  def test_disable_keep_alive_no
    @agent.keep_alive = false

    @agent.disable_keep_alive @req

    assert_equal 'close', @req['connection']
  end

  def test_enable_gzip
    @agent.enable_gzip @req

    assert_equal 'gzip,deflate,identity', @req['accept-encoding']
  end

  def test_enable_gzip_no
    @agent.gzip_enabled = false

    @agent.enable_gzip @req

    assert_equal 'identity', @req['accept-encoding']
  end

  def test_fetch_file_nonexistent
    in_tmpdir do
      nonexistent = File.join Dir.pwd, 'nonexistent'

      uri = URI.parse "file:///#{nonexistent}"

      e = assert_raises Mechanize::ResponseCodeError do
        @agent.fetch uri
      end

      assert_match "404 => Net::HTTPNotFound for #{uri}", e.message
    end
  end

  def test_fetch_file_plus
    Tempfile.open '++plus++' do |io|
      content = 'plusses +++'
      io.write content
      io.rewind

      uri = URI.parse "file://#{Mechanize::Util.uri_escape io.path}"

      page = @agent.fetch uri

      assert_equal content, page.body
      assert_kind_of Mechanize::File, page
    end
  end

  def test_fetch_file_space
    foo = File.expand_path("../htdocs/dir with spaces/foo.html", __FILE__)

    uri = URI.parse "file://#{Mechanize::Util.uri_escape foo}"

    page = @agent.fetch uri

    assert_equal File.read(foo), page.body
    assert_kind_of Mechanize::Page, page
  end

  def test_fetch_head_gzip
    uri = @uri + '/gzip?file=index.html'

    page = @agent.fetch uri, :head

    assert_kind_of Mechanize::Page, page
  end

  def test_fetch_hooks
    @agent.pre_connect_hooks << proc do |agent, request|
      assert_equal '/index.html', request.path
      assert_equal @agent, agent
    end

    @agent.post_connect_hooks << proc do |agent, uri, response, body|
      assert_equal @agent, agent
      assert_equal URI('http://example/index.html'), uri
      assert_equal '200', response.code
      assert_kind_of String, body
    end

    @agent.fetch URI 'http://example/index.html'
  end

  def test_fetch_ignore_bad_chunking
    @agent.ignore_bad_chunking = true

    file = @agent.fetch 'http://example/bad_chunking'

    assert_equal '0123456789', file.content
  end

  def test_fetch_post_connect_hook
    response = nil
    @agent.post_connect_hooks << lambda { |_, _, res, _| response = res }

    @agent.fetch 'http://localhost/'

    assert response
  end

  def test_fetch_redirect_header
    page = @agent.fetch('http://example/redirect', :get,
                        'X-Location' => '/http_headers',
                        'Range' => 'bytes=0-99999')

    assert_match 'range|bytes=0-999', page.body
  end

  def test_fetch_server_error
    e = assert_raises Mechanize::ResponseCodeError do
      @mech.get 'http://localhost/response_code?code=500'
    end

    assert_equal '500', e.response_code
  end

  def test_fetch_allowed_error_codes
    @agent.allowed_error_codes = ['500']

    page = @mech.get 'http://localhost/response_code?code=500'

    assert_equal '500', page.code
  end

  def test_fetch_allowed_error_codes_int
    @agent.allowed_error_codes = [500]

    page = @mech.get 'http://localhost/response_code?code=500'

    assert_equal '500', page.code
  end

  def test_get_meta_refresh_header_follow_self
    @agent.follow_meta_refresh = true
    @agent.follow_meta_refresh_self = true

    page = Mechanize::Page.new(@uri, nil, '', 200, @mech)
    @res.instance_variable_set :@header, 'refresh' => ['0']

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_equal [0.0, URI('http://example/')], refresh
  end

  def test_get_meta_refresh_header_no_follow
    page = Mechanize::Page.new(@uri, nil, '', 200, @mech)
    @res.instance_variable_set :@header, 'refresh' => ['0']

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_nil refresh
  end

  def test_get_meta_refresh_header_no_follow_self
    @agent.follow_meta_refresh = true

    page = Mechanize::Page.new(@uri, nil, '', 200, @mech)
    @res.instance_variable_set :@header, 'refresh' => ['0']

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_nil refresh
  end

  def test_get_meta_refresh_meta_follow_self
    @agent.follow_meta_refresh = true
    @agent.follow_meta_refresh_self = true

    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0">
    BODY

    page = Mechanize::Page.new(@uri, nil, body, 200, @mech)

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_equal [0, nil], refresh
  end

  def test_get_meta_refresh_meta_no_follow
    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0">
    BODY

    page = Mechanize::Page.new(@uri, nil, body, 200, @mech)

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_nil refresh
  end

  def test_get_meta_refresh_meta_no_follow_self
    @agent.follow_meta_refresh = true

    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0">
    BODY

    page = Mechanize::Page.new(@uri, nil, body, 200, @mech)

    refresh = @agent.get_meta_refresh @res, @uri, page

    assert_nil refresh
  end

  def test_get_robots
    robotstxt = @agent.get_robots 'http://localhost/robots.txt'
    refute_equal '', robotstxt

    robotstxt = @agent.get_robots 'http://localhost/response_code?code=404'
    assert_equal '', robotstxt
  end

  def test_hook_content_encoding_response
    @mech.content_encoding_hooks << lambda{|agent, uri, response, response_body_io|
      response['content-encoding'] = 'gzip' if response['content-encoding'] == 'agzip'}

    @res.instance_variable_set :@header, 'content-encoding' => %w[agzip]
    body_io = StringIO.new 'part'
    @agent.hook_content_encoding @res, @uri, body_io

    assert_equal 'gzip', @res['content-encoding']
  end

  def test_http_request_file
    uri = URI.parse 'file:///nonexistent'
    request = @agent.http_request uri, :get

    assert_kind_of Mechanize::FileRequest, request
    assert_equal '/nonexistent', request.path
  end

  def test_http_request_get
    request = @agent.http_request @uri, :get

    assert_kind_of Net::HTTP::Get, request
    assert_equal '/', request.path
  end

  def test_http_request_post
    request = @agent.http_request @uri, :post

    assert_kind_of Net::HTTP::Post, request
    assert_equal '/', request.path
  end

  def test_idle_timeout_equals
    @agent.idle_timeout = 1

    assert_equal 1, @agent.http.idle_timeout
  end

  def test_inflate
    body_io = StringIO.new "x\x9C+H,*\x01\x00\x04?\x01\xB8"

    result = @agent.inflate body_io

    assert_equal 'part', result.read
  end

  def test_post_connect
    @agent.post_connect_hooks << proc { |agent, uri, response, body|
      assert_equal @agent, agent
      assert_equal @res, response
      assert_equal 'body', body
      throw :called
    }

    io = StringIO.new 'body'

    assert_throws :called do
      @agent.post_connect @uri, @res, io
    end

    assert_equal 0, io.pos
  end

  def test_pre_connect
    @agent.pre_connect_hooks << proc { |agent, request|
      assert_equal @agent, agent
      assert_equal @req, request
      throw :called
    }

    assert_throws :called do
      @agent.pre_connect @req
    end
  end

  def test_request_add_headers
    @agent.request_add_headers @req, 'Content-Length' => 300

    assert_equal '300', @req['content-length']
  end

  def test_request_add_headers_etag
    @agent.request_add_headers @req, :etag => '300'

    assert_equal '300', @req['etag']
  end

  def test_request_add_headers_if_modified_since
    @agent.request_add_headers @req, :if_modified_since => 'some_date'

    assert_equal 'some_date', @req['if-modified-since']
  end

  def test_request_add_headers_none
    @agent.request_add_headers @req

    assert_equal @headers, @req.to_hash.keys.sort
  end

  def test_request_add_headers_request_headers
    @agent.request_headers['X-Foo'] = 'bar'

    @agent.request_add_headers @req

    assert_equal @headers + %w[x-foo], @req.to_hash.keys.sort
  end

  def test_request_add_headers_symbol
    e = assert_raises ArgumentError do
      @agent.request_add_headers @req, :content_length => 300
    end

    assert_equal 'unknown header symbol content_length', e.message
  end

  def test_request_auth_basic
    @agent.add_auth @uri, 'user', 'password'

    auth_realm @uri, 'Basic', :basic

    @agent.request_auth @req, @uri

    assert_match %r%^Basic %, @req['Authorization']
  end

  def test_request_auth_digest
    @agent.add_auth @uri, 'user', 'password'

    realm = auth_realm @uri, 'Digest', :digest
    @agent.digest_challenges[realm] = 'Digest realm=r, qop="auth"'

    @agent.request_auth @req, @uri

    assert_match %r%^Digest %, @req['Authorization']
    assert_match %r%qop=auth%, @req['Authorization']

    @req['Authorization'] = nil
    @agent.request_auth @req, @uri

    assert_match %r%^Digest %, @req['Authorization']
    assert_match %r%qop=auth%, @req['Authorization']
  end

  def test_request_auth_iis_digest
    @agent.add_auth @uri, 'user', 'password'

    realm = auth_realm @uri, 'Digest', :digest
    @agent.digest_challenges[realm] = 'Digest realm=r, qop="auth"'

    @agent.request_auth @req, @uri

    assert_match %r%^Digest %, @req['Authorization']
    assert_match %r%qop=auth%, @req['Authorization']
  end

  def test_request_auth_none
    @agent.request_auth @req, @uri

    assert_nil @req['Authorization']
  end

  def test_request_cookies
    uri = URI.parse 'http://host.example.com'
    @agent.cookie_jar.parse 'hello=world domain=.example.com', uri

    @agent.request_cookies @req, uri

    assert_equal 'hello="world domain=.example.com"', @req['Cookie']
  end

  def test_request_cookies_many
    uri = URI.parse 'http://host.example.com'
    cookie_str = 'a=b domain=.example.com, c=d domain=.example.com'
    @agent.cookie_jar.parse cookie_str, uri

    @agent.request_cookies @req, uri

    expected_variant1 = /a="b domain=\.example\.com"; c="d domain=\.example\.com"/
    expected_variant2 = /c="d domain=\.example\.com"; a="b domain=\.example\.com"/

    assert_match(/^(#{expected_variant1}|#{expected_variant2})$/, @req['Cookie'])
  end

  def test_request_cookies_none
    @agent.request_cookies @req, @uri

    assert_nil @req['Cookie']
  end

  def test_request_cookies_wrong_domain
    uri = URI.parse 'http://host.example.com'
    @agent.cookie_jar.parse 'hello=world domain=.example.com', uri

    @agent.request_cookies @req, @uri

    assert_nil @req['Cookie']
  end

  def test_request_host
    @agent.request_host @req, @uri

    assert_equal 'example', @req['host']
  end

  def test_request_host_nonstandard
    @uri.port = 81

    @agent.request_host @req, @uri

    assert_equal 'example:81', @req['host']
  end

  def test_request_language_charset
    @agent.request_language_charset @req

    assert_equal 'en-us,en;q=0.5', @req['accept-language']
    assert_equal 'ISO-8859-1,utf-8;q=0.7,*;q=0.7', @req['accept-charset']
  end

  def test_request_referer
    referer = URI.parse 'http://old.example'

    @agent.request_referer @req, @uri, referer

    assert_equal 'http://old.example', @req['referer']
  end

  def test_request_referer_https
    uri = URI.parse 'https://example'
    referer = URI.parse 'https://old.example'

    @agent.request_referer @req, uri, referer

    assert_equal 'https://old.example', @req['referer']
  end

  def test_request_referer_https_downgrade
    referer = URI.parse 'https://old.example'

    @agent.request_referer @req, @uri, referer

    assert_nil @req['referer']
  end

  def test_request_referer_https_downgrade_case
    uri = URI.parse 'http://example'
    referer = URI.parse 'httpS://old.example'

    @agent.request_referer @req, uri, referer

    assert_nil @req['referer']
  end

  def test_request_referer_https_upgrade
    uri = URI.parse 'https://example'
    referer = URI.parse 'http://old.example'

    @agent.request_referer @req, uri, referer

    assert_equal 'http://old.example', @req['referer']
  end

  def test_request_referer_none
    @agent.request_referer @req, @uri, nil

    assert_nil @req['referer']
  end

  def test_request_referer_strip
    uri = URI.parse 'http://example.com/index.html'

    host_path = "old.example/page.html?q=x"
    referer = "http://#{host_path}"

    [
      "",
      "@",
      "user1@",
      ":@",
      "user1:@",
      ":password1@",
      "user1:password1@",
    ].each { |userinfo|
      ['', '#frag'].each { |frag|
        url = URI.parse "http://#{userinfo}#{host_path}#{frag}"

        @agent.request_referer @req, uri, url

        assert_equal referer, @req['referer'], url
      }
    }
  end

  def test_request_user_agent
    @agent.request_user_agent @req

    assert_match %r%^Mechanize/#{Mechanize::VERSION}%, @req['user-agent']

    ruby_version = if RUBY_PATCHLEVEL >= 0 then
                     "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
                   else
                     "#{RUBY_VERSION}dev#{RUBY_REVISION}"
                   end

    assert_match %r%Ruby/#{ruby_version}%, @req['user-agent']
  end

  def test_resolve_bad_uri
    e = assert_raises ArgumentError do
      @agent.resolve 'google'
    end

    assert_equal 'absolute URL needed (not google)', e.message
  end

  def test_resolve_uri_without_path
    e = assert_raises ArgumentError do
      @agent.resolve 'http:%5C%5Cfoo'
    end

    assert_equal 'hierarchical URL needed (not http:%5C%5Cfoo)', e.message
  end

  def test_resolve_utf8
    uri = 'http://example?q=ü'

    resolved = @agent.resolve uri

    assert_equal '/?q=%C3%BC', resolved.request_uri
  end

  def test_resolve_parameters_body
    input_params = { :q => 'hello' }

    uri, params = @agent.resolve_parameters @uri, :post, input_params

    assert_equal 'http://example/', uri.to_s
    assert_equal input_params, params
  end

  def test_resolve_parameters_query
    uri, params = @agent.resolve_parameters @uri, :get, :q => 'hello'

    assert_equal 'http://example/?q=hello', uri.to_s
    assert_nil params
  end

  def test_resolve_parameters_query_append
    input_params = { :q => 'hello' }
    @uri.query = 'a=b'

    uri, params = @agent.resolve_parameters @uri, :get, input_params

    assert_equal 'http://example/?a=b&q=hello', uri.to_s
    assert_nil params
  end

  def test_resolve_slashes
    page = Mechanize::Page.new URI('http://example/foo/'), nil, '', 200, @mech
    uri = '/bar/http://example/test/'

    resolved = @agent.resolve uri, page

    assert_equal 'http://example/bar/http://example/test/', resolved.to_s
  end

  def test_response_authenticate
    @agent.add_auth @uri, 'user', 'password'

    @res.instance_variable_set :@header, 'www-authenticate' => ['Basic realm=r']

    @agent.response_authenticate @res, nil, @uri, @req, {}, nil, nil

    base_uri = @uri + '/'
    realm = Mechanize::HTTP::AuthRealm.new 'Basic', base_uri, 'r'
    assert_equal [realm], @agent.authenticate_methods[base_uri][:basic]
  end

  def test_response_authenticate_digest
    @agent.add_auth @uri, 'user', 'password'

    @res.instance_variable_set(:@header,
                               'www-authenticate' => ['Digest realm=r'])

    @agent.response_authenticate @res, nil, @uri, @req, {}, nil, nil

    base_uri = @uri + '/'
    realm = Mechanize::HTTP::AuthRealm.new 'Digest', base_uri, 'r'
    assert_equal [realm], @agent.authenticate_methods[base_uri][:digest]

    challenge = Mechanize::HTTP::AuthChallenge.new('Digest',
                                                   { 'realm' => 'r' },
                                                   'Digest realm=r')

    assert_equal challenge, @agent.digest_challenges[realm]
  end

  def test_response_authenticate_digest_iis
    @agent.add_auth @uri, 'user', 'password'

    @res.instance_variable_set(:@header,
                               'www-authenticate' => ['Digest realm=r'],
                               'server'           => ['Microsoft-IIS'])
    @agent.response_authenticate @res, nil, @uri, @req, {}, nil, nil

    base_uri = @uri + '/'
    realm = Mechanize::HTTP::AuthRealm.new 'Digest', base_uri, 'r'
    assert_equal [realm], @agent.authenticate_methods[base_uri][:iis_digest]
  end

  def test_response_authenticate_multiple
    @agent.add_auth @uri, 'user', 'password'

    @res.instance_variable_set(:@header,
                               'www-authenticate' =>
                                 ['Basic realm=r, Digest realm=r'])

    @agent.response_authenticate @res, nil, @uri, @req, {}, nil, nil

    base_uri = @uri + '/'
    realm = Mechanize::HTTP::AuthRealm.new 'Digest', base_uri, 'r'
    assert_equal [realm], @agent.authenticate_methods[base_uri][:digest]

    assert_empty @agent.authenticate_methods[base_uri][:basic]
  end

  def test_response_authenticate_no_credentials
    @res.instance_variable_set :@header, 'www-authenticate' => ['Basic realm=r']

    e = assert_raises Mechanize::UnauthorizedError do
      @agent.response_authenticate @res, fake_page, @uri, @req, {}, nil, nil
    end

    assert_match 'no credentials', e.message
    assert_match 'available realms: r', e.message
  end

  def test_response_authenticate_no_www_authenticate
    @agent.add_auth @uri, 'user', 'password'

    denied_uri = URI('http://example/denied')

    denied = page denied_uri, 'text/html', '', 401

    e = assert_raises Mechanize::UnauthorizedError do
      @agent.response_authenticate @res, denied, @uri, @req, {}, nil, nil
    end

    assert_equal "401 => Net::HTTPUnauthorized for #{denied_uri} -- " \
                 "WWW-Authenticate header missing in response",
                 e.message
  end

  def test_response_authenticate_ntlm
    @uri += '/ntlm'
    @agent.add_auth @uri, 'user', 'password'

    @res.instance_variable_set(:@header,
                               'www-authenticate' => ['Negotiate, NTLM'])

    page = @agent.response_authenticate @res, nil, @uri, @req, {}, nil, nil

    assert_equal 'ok', page.body # lame test
  end

  def test_response_authenticate_unknown
    @agent.add_auth @uri, 'user', 'password'

    page = Mechanize::File.new nil, nil, nil, 401
    @res.instance_variable_set(:@header,
                               'www-authenticate' => ['Unknown realm=r'])

    assert_raises Mechanize::UnauthorizedError do
      @agent.response_authenticate @res, page, @uri, @req, nil, nil, nil
    end
  end

  def test_response_content_encoding_7_bit
    @res.instance_variable_set :@header, 'content-encoding' => %w[7bit]

    body = @agent.response_content_encoding @res, StringIO.new('part')

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_deflate
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]
    body_io = StringIO.new "x\x9C+H,*\x01\x00\x04?\x01\xB8"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read

    assert body_io.closed?
  end

  def test_response_content_encoding_deflate_chunked
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]
    body_io = StringIO.new "x\x9C+H,*\x01\x00\x04?\x01\xB8"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_deflate_corrupt
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]
    body_io = StringIO.new "x\x9C+H,*\x01\x00\x04?\x01" # missing 1 byte

    e = assert_raises Mechanize::Error do
      @agent.response_content_encoding @res, body_io
    end

    assert_match %r%error handling content-encoding deflate:%, e.message
    assert_match %r%Zlib%, e.message

    assert body_io.closed?
  end

  def test_response_content_encoding_deflate_empty
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]

    body = @agent.response_content_encoding @res, StringIO.new

    assert_equal '', body.read
  end

  # IIS/6.0 ASP.NET/2.0.50727 does not wrap deflate with zlib, WTF?
  def test_response_content_encoding_deflate_no_zlib
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]

    body = @agent.response_content_encoding @res, StringIO.new("+H,*\001\000")

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_gzip
    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017I\004\000\000\000"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read

    assert body_io.closed?
  end

  def test_response_content_encoding_gzip_chunked
    def @res.content_length() nil end
    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017I\004\000\000\000"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_gzip_corrupt
    log = StringIO.new
    logger = Logger.new log
    @agent.context.log = logger

    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001"

    return if jruby_zlib?

    e = assert_raises Mechanize::Error do
      @agent.response_content_encoding @res, body_io
    end

    assert_match %r%error handling content-encoding gzip:%, e.message
    assert_match %r%Zlib%, e.message

    assert_match %r%unable to gunzip response: unexpected end of file%,
                 log.string
    assert_match %r%unable to inflate response: buffer error%,
                 log.string

    assert body_io.closed?
  end

  def test_response_content_encoding_gzip_checksum_corrupt_crc
    log = StringIO.new
    logger = Logger.new log
    @agent.context.log = logger

    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017J\004\000\000\000"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read

    assert body_io.closed?

    assert_match %r%invalid compressed data -- crc error%, log.string
  rescue IOError
    raise unless jruby_zlib?
  end

  def test_response_content_encoding_gzip_checksum_corrupt_length
    log = StringIO.new
    logger = Logger.new log
    @agent.context.log = logger

    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017I\005\000\000\000"

    @agent.response_content_encoding @res, body_io

    assert body_io.closed?

    assert_match %r%invalid compressed data -- length error%, log.string
  rescue IOError
    raise unless jruby_zlib?
  end

  def test_response_content_encoding_gzip_checksum_truncated
    log = StringIO.new
    logger = Logger.new log
    @agent.context.log = logger

    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017I\004\000\000"

    @agent.response_content_encoding @res, body_io

    assert body_io.closed?

    assert_match %r%unable to gunzip response: footer is not found%, log.string
  rescue IOError
    raise unless jruby_zlib?
  end

  def test_response_content_encoding_gzip_empty
    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]

    body = @agent.response_content_encoding @res, StringIO.new

    assert_equal '', body.read
  end

  def test_response_content_encoding_gzip_encoding_bad
    @res.instance_variable_set(:@header,
                               'content-encoding' => %w[gzip],
                               'content-type' => 'text/html; charset=UTF-8')

    # "test\xB2"
    body_io = StringIO.new \
      "\037\213\b\000*+\314N\000\003+I-.\331\004\000x\016\003\376\005\000\000\000"

    body = @agent.response_content_encoding @res, body_io

    expected = "test\xB2"
    expected.force_encoding Encoding::BINARY if have_encoding?

    content = body.read
    assert_equal expected, content
    assert_equal Encoding::BINARY, content.encoding if have_encoding?
  end

  def test_response_content_encoding_gzip_no_footer
    @res.instance_variable_set :@header, 'content-encoding' => %w[gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read

    assert body_io.closed?
  rescue IOError
    raise unless jruby_zlib?
  end

  def test_response_content_encoding_none
    @res.instance_variable_set :@header, 'content-encoding' => %w[none]

    body = @agent.response_content_encoding @res, StringIO.new('part')

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_empty_string
    @res.instance_variable_set :@header, 'content-encoding' => %w[]

    body = @agent.response_content_encoding @res, StringIO.new('part')

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_identity
    @res.instance_variable_set :@header, 'content-encoding' => %w[identity]

    body = @agent.response_content_encoding @res, StringIO.new('part')

    assert_equal 'part', body.read
  end

  def test_response_content_encoding_tempfile_7_bit
    body_io = tempfile 'part'

    @res.instance_variable_set :@header, 'content-encoding' => %w[7bit]

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read
    refute body_io.closed?
  ensure
    begin
      body_io.close! if body_io and not body_io.closed?
    rescue IOError
      # HACK for ruby 1.8
    end
  end

  def test_response_content_encoding_tempfile_gzip
    body_io = tempfile "x\x9C+H,*\x01\x00\x04?\x01\xB8"
    @res.instance_variable_set :@header, 'content-encoding' => %w[deflate]

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read
    assert body_io.closed?
  ensure
    body_io.close! if body_io and not body_io.closed?
  end

  def test_response_content_encoding_unknown
    @res.instance_variable_set :@header, 'content-encoding' => %w[unknown]
    body = StringIO.new 'part'

    e = assert_raises Mechanize::Error do
      @agent.response_content_encoding @res, body
    end

    assert_equal 'unsupported content-encoding: unknown', e.message
  end

  def test_response_content_encoding_x_gzip
    @res.instance_variable_set :@header, 'content-encoding' => %w[x-gzip]
    body_io = StringIO.new \
      "\037\213\b\0002\002\225M\000\003+H,*\001\000\306p\017I\004\000\000\000"

    body = @agent.response_content_encoding @res, body_io

    assert_equal 'part', body.read
  end

  def test_response_cookies
    uri = URI.parse 'http://host.example.com'
    cookie_str = 'a=b domain=.example.com'
    @res.instance_variable_set(:@header,
                               'set-cookie' => [cookie_str],
                               'content-type' => %w[text/html])
    page = Mechanize::Page.new uri, @res, '', 200, @mech

    @agent.response_cookies @res, uri, page

    assert_equal ['a="b domain=.example.com"'],
                 @agent.cookie_jar.cookies(uri).map { |c| c.to_s }
  end

  def test_response_cookies_many
    uri = URI.parse 'http://host.example.com'
    cookie1 = 'a=b domain=.example.com'
    cookie2 = 'c=d domain=.example.com'
    cookies = [cookie1, cookie2]
    @res.instance_variable_set(:@header,
                               'set-cookie' => cookies,
                               'content-type' => %w[text/html])
    page = Mechanize::Page.new uri, @res, '', 200, @mech

    @agent.response_cookies @res, uri, page

    cookies_from_jar = @agent.cookie_jar.cookies(uri)

    assert_equal 2, cookies_from_jar.length
    assert_equal [
      'a="b domain=.example.com"',
      'c="d domain=.example.com"',
    ], cookies_from_jar.sort_by { |c| c.name }.map(&:to_s)
  end

  def test_response_cookies_meta
    uri = URI.parse 'http://host.example.com'
    cookie_str = 'a=b domain=.example.com'

    body = <<-BODY
<head>
  <meta http-equiv="Set-Cookie" content="#{cookie_str}">
</head>"
    BODY

    @res.instance_variable_set(:@header,
                               'content-type' => %w[text/html])
    page = Mechanize::Page.new uri, @res, body, 200, @mech

    @agent.response_cookies @res, uri, page

    assert_equal ['a="b domain=.example.com"'],
                 @agent.cookie_jar.cookies(uri).map { |c| c.to_s }
  end

  def test_response_cookies_meta_bogus
    uri = URI.parse 'http://host.example.com'

    body = <<-BODY
<head>
  <meta http-equiv="Set-Cookie">
</head>"
    BODY

    @res.instance_variable_set(:@header,
                               'content-type' => %w[text/html])
    page = Mechanize::Page.new uri, @res, body, 200, @mech

    @agent.response_cookies @res, uri, page

    assert_empty @agent.cookie_jar.cookies(uri)
  end

  def test_response_follow_meta_refresh
    uri = URI.parse 'http://example/#id+1'

    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0">
    BODY

    page = Mechanize::Page.new(uri, nil, body, 200, @mech)

    @agent.follow_meta_refresh = true
    @agent.follow_meta_refresh_self = true

    page = @agent.response_follow_meta_refresh @res, uri, page, 0

    assert_equal uri, page.uri
  end

  def test_response_follow_meta_refresh_limit
    uri = URI.parse 'http://example/#id+1'

    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0">
    BODY

    page = Mechanize::Page.new(uri, nil, body, 200, @mech)

    @agent.follow_meta_refresh = true
    @agent.follow_meta_refresh_self = true

    assert_raises Mechanize::RedirectLimitReachedError do
      @agent.response_follow_meta_refresh(@res, uri, page,
                                          @agent.redirection_limit)
    end
  end

  def test_response_meta_refresh_with_insecure_url
    uri = URI.parse 'http://example/#id+1'

    body = <<-BODY
<title></title>
<meta http-equiv="refresh" content="0; url=file:///dev/zero">
    BODY

    page = Mechanize::Page.new(uri, nil, body, 200, @mech)

    @agent.follow_meta_refresh = true

    assert_raises Mechanize::Error do
      @agent.response_follow_meta_refresh(@res, uri, page,
                                          @agent.redirection_limit)
    end
  end

  def test_response_parse
    body = '<title>hi</title>'
    @res.instance_variable_set :@header, 'content-type' => %w[text/html]

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page
    assert_equal @mech, page.mech
  end

  def test_response_parse_content_type_case
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header, 'content-type' => %w[text/HTML])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page

    assert_equal 'text/HTML', page.content_type
  end

  def test_response_parse_content_type_encoding
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header,
                               'content-type' =>
                                 %w[text/html;charset=ISO-8859-1])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page
    assert_equal @mech, page.mech

    assert_equal 'ISO-8859-1', page.encoding
    assert_equal 'ISO-8859-1', page.parser.encoding
  end

  def test_response_parse_content_type_encoding_broken_iso_8859_1
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header,
                               'content-type' =>
                                 %w[text/html; charset=ISO_8859-1])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page
    assert_equal 'ISO_8859-1', page.encoding
  end

  def test_response_parse_content_type_encoding_broken_utf_8
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header,
                               'content-type' =>
                                 %w[text/html; charset=UTF8])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page
    assert_equal 'UTF8', page.encoding
    assert_equal 'UTF8', page.parser.encoding
  end

  def test_response_parse_content_type_encoding_garbage
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header,
                               'content-type' =>
                                 %w[text/html; charset=garbage_charset])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page
    assert_equal @mech, page.mech
  end

  def test_response_parse_content_type_encoding_semicolon
    body = '<title>hi</title>'
    @res.instance_variable_set(:@header,
                               'content-type' =>
                                 %w[text/html;charset=UTF-8;])

    page = @agent.response_parse @res, body, @uri

    assert_instance_of Mechanize::Page, page

    assert_equal 'UTF-8', page.encoding
  end

  def test_response_read
    def @res.read_body() yield 'part' end
    def @res.content_length() 4 end

    io = @agent.response_read @res, @req, @uri

    body = io.read

    assert_equal 'part', body
    assert_equal Encoding::BINARY, body.encoding
  end

  def test_response_read_chunked_no_trailer
    @res['Transfer-Encoding'] = 'chunked'
    def @res.content_length() end
    def @res.read_body
      yield 'a' * 10
      raise EOFError
    end

    e = assert_raises Mechanize::ChunkedTerminationError do
      @agent.response_read @res, @req, @uri
    end

    assert_equal 'aaaaaaaaaa', e.body_io.read
  end

  def test_response_read_content_length_head
    req = Net::HTTP::Head.new '/'

    def @res.content_length() end
    def @res.read_body() end

    io = @agent.response_read @res, req, @uri

    assert_equal '', io.read
  end

  def test_response_read_content_length_mismatch
    def @res.content_length() 5 end
    def @res.read_body() yield 'part' end

    e = assert_raises Mechanize::ResponseReadError do
      @agent.response_read @res, @req, @uri
    end

    assert_equal 'Content-Length (5) does not match response body length (4)' \
      ' (Mechanize::ResponseReadError)', e.message
  end

  def test_response_read_content_length_redirect
    res = Net::HTTPFound.allocate
    def res.content_length() 5 end
    def res.code() 302 end
    def res.read_body() yield 'part' end
    res.instance_variable_set :@header, {}

    io = @agent.response_read res, @req, @uri

    assert_equal 'part', io.read
  end

  def test_response_read_error
    def @res.read_body()
      yield 'part'
      raise Net::HTTP::Persistent::Error
    end

    e = assert_raises Mechanize::ResponseReadError do
      @agent.response_read @res, @req, @uri
    end

    assert_equal @res, e.response
    assert_equal 'part', e.body_io.read
    assert_kind_of Net::HTTP::Persistent::Error, e.error
  end

  def test_response_read_file
    Tempfile.open 'pi.txt' do |tempfile|
      tempfile.write "π\n"
      tempfile.flush
      tempfile.rewind

      uri = URI.parse "file://#{tempfile.path}"
      req = Mechanize::FileRequest.new uri
      res = Mechanize::FileResponse.new tempfile.path

      io = @agent.response_read res, req, uri

      expected = "π\n".force_encoding(Encoding::BINARY)

      # Ruby 1.8.7 doesn't let us set the write mode of the tempfile to binary,
      # so we should expect an inserted carriage return on some platforms
      expected_with_carriage_return = "π\r\n".force_encoding(Encoding::BINARY)

      body = io.read
      assert_match(/^(#{expected}|#{expected_with_carriage_return})$/m, body)
      assert_equal Encoding::BINARY, body.encoding
    end
  end

  def test_response_read_large
    @agent.max_file_buffer = 10240

    def @res.read_body() yield 'a' * 10241 end
    def @res.content_length() 10241 end

    io = @agent.response_read @res, @req, @uri

    assert_kind_of Tempfile, io
    assert_equal 10241, io.stat.size
  end

  def test_response_read_large_chunked
    @agent.max_file_buffer = 10240

    def @res.read_body
      11.times do yield 'a' * 1024 end
    end
    def @res.content_length() end

    io = @agent.response_read @res, @req, @uri

    assert_kind_of Tempfile, io
    assert_equal 11264, io.stat.size
  end

  def test_response_read_no_body
    req = Net::HTTP::Options.new '/'

    def @res.content_length() end
    def @res.read_body() end

    io = @agent.response_read @res, req, @uri

    assert_equal '', io.read
  end

  def test_response_read_unknown_code
    res = Net::HTTPUnknownResponse.allocate
    res.instance_variable_set :@code, 9999
    res.instance_variable_set :@header, {}
    def res.read_body() yield 'part' end

    e = assert_raises Mechanize::ResponseCodeError do
      @agent.response_read res, @req, @uri
    end

    assert_equal res, e.page
  end

  def test_response_redirect
    @agent.redirect_ok = true
    referer = page 'http://example/referer'

    page = fake_page
    page = @agent.response_redirect({ 'Location' => '/index.html' }, :get,
                                    page, 0, {}, referer)

    assert_equal URI('http://fake.example/index.html'), page.uri

    assert_equal 'http://example/referer', requests.first['Referer']
  end

  def test_response_redirect_header
    @agent.redirect_ok = true
    referer = page 'http://example/referer'

    headers = {
      'Range' => 'bytes=0-9999',
      'Content-Type' => 'application/x-www-form-urlencoded',
      'Content-Length' => '9999',
    }

    page = fake_page
    page = @agent.response_redirect({ 'Location' => '/http_headers' }, :get,
                                    page, 0, headers, referer)

    assert_equal URI('http://fake.example/http_headers'), page.uri

    assert_match 'range|bytes=0-9999', page.body
    refute_match 'content-type|application/x-www-form-urlencoded', page.body
    refute_match 'content-length|9999', page.body
  end

  def test_response_redirect_malformed
    @agent.redirect_ok = true
    referer = page 'http://example/referer'

    page = fake_page
    page = @agent.response_redirect({ 'Location' => '/index.html?q=あ' }, :get,
                                    page, 0, {}, referer)

    assert_equal URI('http://fake.example/index.html?q=%E3%81%82'), page.uri

    assert_equal 'http://example/referer', requests.first['Referer']
  end

  def test_response_redirect_insecure
    @agent.redirect_ok = true
    referer = page 'http://example/referer'

    assert_raises Mechanize::Error do
      @agent.response_redirect({ 'Location' => 'file:///etc/passwd' }, :get,
                               fake_page, 0, {}, referer)
    end
  end

  def test_response_redirect_limit
    @agent.redirect_ok = true
    referer = page 'http://example/referer'

    assert_raises Mechanize::RedirectLimitReachedError do
      @agent.response_redirect({ 'Location' => '/index.html' }, :get,
                               fake_page, @agent.redirection_limit, {}, referer)
    end
  end

  def test_response_redirect_not_ok
    @agent.redirect_ok = false

    page = fake_page
    page = @agent.response_redirect({ 'Location' => '/other' }, :get, page, 0,
                                    {}, page)

    assert_equal URI('http://fake.example'), page.uri
  end

  def test_response_redirect_permanent
    @agent.redirect_ok = :permanent

    response = Net::HTTPMovedPermanently.allocate
    response.instance_variable_set :@header, { 'location' => %w[/index.html] }

    page = fake_page
    page = @agent.response_redirect response, :get, page, 0, {}, page

    assert_equal URI('http://fake.example/index.html'), page.uri
  end

  def test_response_redirect_permanent_temporary
    @agent.redirect_ok = :permanent

    response = Net::HTTPMovedTemporarily.allocate
    response.instance_variable_set :@header, { 'location' => %w[/index.html] }

    page = fake_page
    page = @agent.response_redirect response, :get, page, 0, {}, page

    assert_equal URI('http://fake.example/'), page.uri
  end

  def test_retry_change_request_equals
    refute @agent.http.retry_change_requests

    @agent.retry_change_requests = true

    assert @agent.http.retry_change_requests
  end

  def test_robots_allowed_eh
    allowed    = URI 'http://localhost/index.html'
    disallowed = URI 'http://localhost/norobots.html'

    assert @agent.robots_allowed? allowed
    refute @agent.robots_allowed? disallowed

    refute @agent.robots_disallowed? allowed
    assert @agent.robots_disallowed? disallowed
  end

  def test_robots_allowed_eh_noindex
    @agent.robots = true

    noindex = URI 'http://localhost/noindex.html'

    assert @agent.robots_allowed? noindex

    assert_raises Mechanize::RobotsDisallowedError do
      @agent.fetch noindex
    end
  end

  def test_robots_infinite_loop
    @agent.robots = true
    @agent.redirect_ok = true

    assert_raises Mechanize::RobotsDisallowedError do
      @agent.fetch URI('http://301/norobots.html')
    end

    @agent.fetch URI('http://301/robots.html')
  end

  def test_set_proxy
    @agent.set_proxy 'www.example.com', 9001, 'joe', 'lol'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_port_string
    @agent.set_proxy 'www.example.com', '9001', 'joe', 'lol'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_service_name
    @agent.set_proxy 'www.example.com', 'http', 'joe', 'lol'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     80
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_service_name_bad
    e = assert_raises ArgumentError do
      @agent.set_proxy 'www.example.com', 'nonexistent service', 'joe', 'lol'
    end

    assert_equal 'invalid value for port: "nonexistent service"', e.message
  end

  def test_set_proxy_with_scheme
    @agent.set_proxy 'http://www.example.com', 9001, 'joe', 'lol'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_url
    @agent.set_proxy 'http://joe:lol@www.example.com:9001'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_uri
    @agent.set_proxy URI('http://joe:lol@www.example.com:9001')

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_set_proxy_url_and_credentials
    @agent.set_proxy 'http://www.example.com:9001', nil, 'joe', 'lol'

    assert_equal @agent.proxy_uri.host,     'www.example.com'
    assert_equal @agent.proxy_uri.port,     9001
    assert_equal @agent.proxy_uri.user,     'joe'
    assert_equal @agent.proxy_uri.password, 'lol'
  end

  def test_setting_agent_name
    mech = Mechanize.new 'user-set-name'
    assert_equal 'user-set-name', mech.agent.http.name
  end

  def test_ssl
    in_tmpdir do
      store = OpenSSL::X509::Store.new
      @agent.ca_file = '.'
      @agent.cert_store = store
      @agent.certificate = ssl_certificate
      @agent.private_key = ssl_private_key
      @agent.ssl_version = 'SSLv3'
      @agent.verify_callback = proc { |ok, context| }

      http = @agent.http

      assert_equal '.',                       http.ca_file
      assert_equal store,                     http.cert_store
      assert_equal ssl_certificate,           http.certificate
      assert_equal ssl_private_key,           http.private_key
      assert_equal 'SSLv3',                   http.ssl_version
      assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
      assert http.verify_callback
    end
  end

  def test_use_tempfile_eh
    refute @agent.use_tempfile? nil

    @agent.max_file_buffer = 1

    refute @agent.use_tempfile? 0
    assert @agent.use_tempfile? 1

    @agent.max_file_buffer = nil

    refute @agent.use_tempfile? 1
  end

  def test_verify_none_equals
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http = @agent.http

    assert_equal OpenSSL::SSL::VERIFY_NONE, http.verify_mode
  end

end

