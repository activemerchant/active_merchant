require 'tempfile'
require 'net/ntlm'
require 'kconv'
require 'webrobots'

##
# An HTTP (and local disk access) user agent.  This class is an implementation
# detail and is subject to change at any time.

class Mechanize::HTTP::Agent

  # :section: Headers

  # Disables If-Modified-Since conditional requests (enabled by default)
  attr_accessor :conditional_requests

  # Is gzip compression of requests enabled?
  attr_accessor :gzip_enabled

  # A hash of request headers to be used for every request
  attr_accessor :request_headers

  # The User-Agent header to send
  attr_reader :user_agent

  # :section: History

  # history of requests made
  attr_accessor :history

  # :section: Hooks

  # A list of hooks to call after retrieving a response.  Hooks are called with
  # the agent and the response returned.
  attr_reader :post_connect_hooks

  # A list of hooks to call before making a request.  Hooks are called with
  # the agent and the request to be performed.
  attr_reader :pre_connect_hooks

  # A list of hooks to call to handle the content-encoding of a request.
  attr_reader :content_encoding_hooks

  # :section: HTTP Authentication

  attr_reader :auth_store # :nodoc:
  attr_reader :authenticate_methods # :nodoc:
  attr_reader :digest_challenges # :nodoc:

  # :section: Redirection

  # Follow HTML meta refresh and HTTP Refresh.  If set to +:anywhere+ meta
  # refresh tags outside of the head element will be followed.
  attr_accessor :follow_meta_refresh

  # Follow an HTML meta refresh that has no "url=" in the content attribute.
  #
  # Defaults to false to prevent infinite refresh loops.
  attr_accessor :follow_meta_refresh_self

  # Controls how this agent deals with redirects.  The following values are
  # allowed:
  #
  # :all, true:: All 3xx redirects are followed (default)
  # :permanent:: Only 301 Moved Permanantly redirects are followed
  # false:: No redirects are followed
  attr_accessor :redirect_ok

  # Maximum number of redirects to follow
  attr_accessor :redirection_limit

  # :section: Allowed error codes

  # List of error codes (in String or Integer) to handle without
  # raising Mechanize::ResponseCodeError, defaulted to an empty array.
  # Note that 2xx, 3xx and 401 status codes will be handled without
  # checking this list.

  attr_accessor :allowed_error_codes

  # :section: Robots

  # When true, this agent will consult the site's robots.txt for each access.
  attr_reader :robots

  # Mutex used when fetching robots.txt
  attr_reader :robots_mutex

  # :section: SSL

  # OpenSSL key password
  attr_accessor :pass

  # :section: Timeouts

  # Set to false to disable HTTP/1.1 keep-alive requests
  attr_accessor :keep_alive

  # Length of time to wait until a connection is opened in seconds
  attr_accessor :open_timeout

  # Length of time to attempt to read data from the server
  attr_accessor  :read_timeout

  # :section:

  # The cookies for this agent
  attr_accessor :cookie_jar

  # Responses larger than this will be written to a Tempfile instead of stored
  # in memory.  Setting this to nil disables creation of Tempfiles.
  attr_accessor :max_file_buffer

  # :section: Utility

  # The context parses responses into pages
  attr_accessor :context

  attr_reader :http # :nodoc:

  # When set to true mechanize will ignore an EOF during chunked transfer
  # encoding so long as at least one byte was received.  Be careful when
  # enabling this as it may cause data loss.
  attr_accessor :ignore_bad_chunking

  # Handlers for various URI schemes
  attr_accessor :scheme_handlers

  # :section:

  # Creates a new Mechanize HTTP user agent.  The user agent is an
  # implementation detail of mechanize and its API may change at any time.

  # The connection_name can be used to segregate SSL connections.
  # Agents with different names will not share the same persistent connection.
  def initialize(connection_name = 'mechanize')
    @allowed_error_codes      = []
    @conditional_requests     = true
    @context                  = nil
    @content_encoding_hooks   = []
    @cookie_jar               = Mechanize::CookieJar.new
    @follow_meta_refresh      = false
    @follow_meta_refresh_self = false
    @gzip_enabled             = true
    @history                  = Mechanize::History.new
    @ignore_bad_chunking      = false
    @keep_alive               = true
    @max_file_buffer          = 100_000 # 5MB for response bodies
    @open_timeout             = nil
    @post_connect_hooks       = []
    @pre_connect_hooks        = []
    @read_timeout             = nil
    @redirect_ok              = true
    @redirection_limit        = 20
    @request_headers          = {}
    @robots                   = false
    @robots_mutex             = Mutex.new
    @user_agent               = nil
    @webrobots                = nil

    # HTTP Authentication
    @auth_store           = Mechanize::HTTP::AuthStore.new
    @authenticate_parser  = Mechanize::HTTP::WWWAuthenticateParser.new
    @authenticate_methods = Hash.new do |methods, uri|
      methods[uri] = Hash.new do |realms, auth_scheme|
        realms[auth_scheme] = []
      end
    end
    @digest_auth          = Net::HTTP::DigestAuth.new
    @digest_challenges    = {}

    # SSL
    @pass = nil

    @scheme_handlers = Hash.new { |h, scheme|
      h[scheme] = lambda { |link, page|
        raise Mechanize::UnsupportedSchemeError.new(scheme, link)
      }
    }

    @scheme_handlers['http']      = lambda { |link, page| link }
    @scheme_handlers['https']     = @scheme_handlers['http']
    @scheme_handlers['relative']  = @scheme_handlers['http']
    @scheme_handlers['file']      = @scheme_handlers['http']

    @http =
      if defined?(Net::HTTP::Persistent::DEFAULT_POOL_SIZE)
        Net::HTTP::Persistent.new(name: connection_name)
      else
        # net-http-persistent < 3.0
        Net::HTTP::Persistent.new(connection_name)
      end
    @http.idle_timeout = 5
    @http.keep_alive   = 300
  end

  ##
  # Adds credentials +user+, +pass+ for +uri+.  If +realm+ is set the
  # credentials are used only for that realm.  If +realm+ is not set the
  # credentials become the default for any realm on that URI.
  #
  # +domain+ and +realm+ are exclusive as NTLM does not follow RFC 2617.  If
  # +domain+ is given it is only used for NTLM authentication.

  def add_auth uri, user, password, realm = nil, domain = nil
    @auth_store.add_auth uri, user, password, realm, domain
  end

  ##
  # USE OF add_default_auth IS NOT RECOMMENDED AS IT MAY EXPOSE PASSWORDS TO
  # THIRD PARTIES
  #
  # Adds credentials +user+, +pass+ as the default authentication credentials.
  # If no other credentials are available  these will be returned from
  # credentials_for.
  #
  # If +domain+ is given it is only used for NTLM authentication.

  def add_default_auth user, password, domain = nil # :nodoc:
    @auth_store.add_default_auth user, password, domain
  end

  ##
  # Retrieves +uri+ and parses it into a page or other object according to
  # PluggableParser.  If the URI is an HTTP or HTTPS scheme URI the given HTTP
  # +method+ is used to retrieve it, along with the HTTP +headers+, request
  # +params+ and HTTP +referer+.
  #
  # The final URI to access is built with +uri+ and +params+, the
  # latter of which is formatted into a string using
  # Mechanize::Util.build_query_string, which see.
  #
  # +redirects+ tracks the number of redirects experienced when retrieving the
  # page.  If it is over the redirection_limit an error will be raised.

  def fetch uri, method = :get, headers = {}, params = [],
            referer = current_page, redirects = 0

    referer_uri = referer ? referer.uri : nil
    uri         = resolve uri, referer
    uri, params = resolve_parameters uri, method, params
    request     = http_request uri, method, params
    connection  = connection_for uri

    request_auth             request, uri
    disable_keep_alive       request
    enable_gzip              request
    request_language_charset request
    request_cookies          request, uri
    request_host             request, uri
    request_referer          request, uri, referer_uri
    request_user_agent       request
    request_add_headers      request, headers
    pre_connect              request

    # Consult robots.txt
    if robots && uri.is_a?(URI::HTTP)
      robots_allowed?(uri) or raise Mechanize::RobotsDisallowedError.new(uri)
    end

    # Add If-Modified-Since if page is in history
    if page = visited_page(uri) and last_modified = page.response['Last-Modified']
      request['If-Modified-Since'] = last_modified
    end if @conditional_requests

    # Specify timeouts if supplied and our connection supports them
    if @open_timeout && connection.respond_to?(:open_timeout=)
      connection.open_timeout = @open_timeout
    end
    if @read_timeout && connection.respond_to?(:read_timeout=)
      connection.read_timeout = @read_timeout
    end

    request_log request

    response_body_io = nil

    # Send the request
    begin
      response = connection.request(uri, request) { |res|
        response_log res

        response_body_io = response_read res, request, uri

        res
      }
    rescue Mechanize::ChunkedTerminationError => e
      raise unless @ignore_bad_chunking

      response = e.response
      response_body_io = e.body_io
    end

    hook_content_encoding response, uri, response_body_io

    response_body_io = response_content_encoding response, response_body_io if
      request.response_body_permitted?

    post_connect uri, response, response_body_io

    page = response_parse response, response_body_io, uri

    response_cookies response, uri, page

    meta = response_follow_meta_refresh response, uri, page, redirects
    return meta if meta

    if robots && page.is_a?(Mechanize::Page)
      page.parser.noindex? and raise Mechanize::RobotsDisallowedError.new(uri)
    end

    case response
    when Net::HTTPSuccess
      page
    when Mechanize::FileResponse
      page
    when Net::HTTPNotModified
      log.debug("Got cached page") if log
      visited_page(uri) || page
    when Net::HTTPRedirection
      response_redirect response, method, page, redirects, headers, referer
    when Net::HTTPUnauthorized
      response_authenticate(response, page, uri, request, headers, params,
                            referer)
    else
      if @allowed_error_codes.any? {|code| code.to_s == page.code} then
        page
      else
        raise Mechanize::ResponseCodeError.new(page, 'unhandled response')
      end
    end
  end

  # URI for a proxy connection

  def proxy_uri
    @http.proxy_uri
  end

  # Retry non-idempotent requests?
  def retry_change_requests
    @http.retry_change_requests
  end

  # Retry non-idempotent requests

  def retry_change_requests= retri
    @http.retry_change_requests = retri
  end

  # :section: Headers

  def user_agent= user_agent
    @webrobots = nil if user_agent != @user_agent
    @user_agent = user_agent
  end

  # :section: History

  # Equivalent to the browser back button.  Returns the most recent page
  # visited.
  def back
    @history.pop
  end

  ##
  # Returns the latest page loaded by the agent

  def current_page
    @history.last
  end

  # Returns the maximum size for the history stack.
  def max_history
    @history.max_size
  end

  # Set the maximum size for the history stack.
  def max_history=(length)
    @history.max_size = length
  end

  # Returns a visited page for the url passed in, otherwise nil
  def visited_page url
    @history.visited_page resolve url
  end

  # :section: Hooks

  def hook_content_encoding response, uri, response_body_io
    @content_encoding_hooks.each do |hook|
      hook.call self, uri, response, response_body_io
    end
  end

  ##
  # Invokes hooks added to post_connect_hooks after a +response+ is returned
  # and the response +body+ is handled.
  #
  # Yields the +context+, the +uri+ for the request, the +response+ and the
  # response +body+.

  def post_connect uri, response, body_io # :yields: agent, uri, response, body
    @post_connect_hooks.each do |hook|
      begin
        hook.call self, uri, response, body_io.read
      ensure
        body_io.rewind
      end
    end
  end

  ##
  # Invokes hooks added to pre_connect_hooks before a +request+ is made.
  # Yields the +agent+ and the +request+ that will be performed to each hook.

  def pre_connect request # :yields: agent, request
    @pre_connect_hooks.each do |hook|
      hook.call self, request
    end
  end

  # :section: Request

  def connection_for uri
    case uri.scheme.downcase
    when 'http', 'https' then
      return @http
    when 'file' then
      return Mechanize::FileConnection.new
    end
  end

  # Closes all open connections for this agent.
  def shutdown
    http.shutdown
  end

  ##
  # Decodes a gzip-encoded +body_io+.  If it cannot be decoded, inflate is
  # tried followed by raising an error.

  def content_encoding_gunzip body_io
    log.debug('gzip response') if log

    zio = Zlib::GzipReader.new body_io
    out_io = auto_io 'mechanize-gunzip', 16384, zio
    zio.finish

    return out_io
  rescue Zlib::Error => gz_error
    log.warn "unable to gunzip response: #{gz_error} (#{gz_error.class})" if
      log

    body_io.rewind
    body_io.read 10

    begin
      log.warn "trying raw inflate on response" if log
      return inflate body_io, -Zlib::MAX_WBITS
    rescue Zlib::Error => e
      log.error "unable to inflate response: #{e} (#{e.class})" if log
      raise
    end
  ensure
    # do not close a second time if we failed the first time
    zio.close if zio and !(zio.closed? or gz_error)
    body_io.close unless body_io.closed?
  end

  ##
  # Decodes a deflate-encoded +body_io+.  If it cannot be decoded, raw inflate
  # is tried followed by raising an error.

  def content_encoding_inflate body_io
    log.debug('deflate body') if log

    return inflate body_io
  rescue Zlib::Error
    log.error('unable to inflate response, trying raw deflate') if log

    body_io.rewind

    begin
      return inflate body_io, -Zlib::MAX_WBITS
    rescue Zlib::Error => e
      log.error("unable to inflate response: #{e}") if log
      raise
    end
  ensure
    body_io.close
  end

  def disable_keep_alive request
    request['connection'] = 'close' unless @keep_alive
  end

  def enable_gzip request
    request['accept-encoding'] = if @gzip_enabled
                                   'gzip,deflate,identity'
                                 else
                                   'identity'
                                 end
  end

  def http_request uri, method, params = nil
    case uri.scheme.downcase
    when 'http', 'https' then
      klass = Net::HTTP.const_get(method.to_s.capitalize)

      request ||= klass.new(uri.request_uri)
      request.body = params.first if params

      request
    when 'file' then
      Mechanize::FileRequest.new uri
    end
  end

  def request_add_headers request, headers = {}
    @request_headers.each do |k,v|
      request[k] = v
    end

    headers.each do |field, value|
      case field
      when :etag              then request["ETag"] = value
      when :if_modified_since then request["If-Modified-Since"] = value
      when Symbol then
        raise ArgumentError, "unknown header symbol #{field}"
      else
        request[field] = value
      end
    end
  end

  def request_auth request, uri
    base_uri = uri + '/'
    base_uri.user     &&= nil
    base_uri.password &&= nil
    schemes = @authenticate_methods[base_uri]

    if realm = schemes[:digest].find { |r| r.uri == base_uri } then
      request_auth_digest request, uri, realm, base_uri, false
    elsif realm = schemes[:iis_digest].find { |r| r.uri == base_uri } then
      request_auth_digest request, uri, realm, base_uri, true
    elsif realm = schemes[:basic].find { |r| r.uri == base_uri } then
      user, password, = @auth_store.credentials_for uri, realm.realm
      request.basic_auth user, password
    end
  end

  def request_auth_digest request, uri, realm, base_uri, iis
    challenge = @digest_challenges[realm]

    uri.user, uri.password, = @auth_store.credentials_for uri, realm.realm

    auth = @digest_auth.auth_header uri, challenge.to_s, request.method, iis
    request['Authorization'] = auth
  end

  def request_cookies request, uri
    return if @cookie_jar.empty? uri

    cookies = @cookie_jar.cookies uri

    return if cookies.empty?

    request.add_field 'Cookie', cookies.join('; ')
  end

  def request_host request, uri
    port = [80, 443].include?(uri.port.to_i) ? nil : uri.port
    host = uri.host

    request['Host'] = [host, port].compact.join ':'
  end

  def request_language_charset request
    request['accept-charset']  = 'ISO-8859-1,utf-8;q=0.7,*;q=0.7'
    request['accept-language'] = 'en-us,en;q=0.5'
  end

  # Log specified headers for the request
  def request_log request
    return unless log

    log.info("#{request.class}: #{request.path}")

    request.each_header do |k, v|
      log.debug("request-header: #{k} => #{v}")
    end
  end

  # Sets a Referer header.  Fragment part is removed as demanded by
  # RFC 2616 14.36, and user information part is removed just like
  # major browsers do.
  def request_referer request, uri, referer
    return unless referer
    return if 'https'.casecmp(referer.scheme) == 0 and
              'https'.casecmp(uri.scheme) != 0
    if referer.fragment || referer.user || referer.password
      referer = referer.dup
      referer.fragment = referer.user = referer.password = nil
    end
    request['Referer'] = referer
  end

  def request_user_agent request
    request['User-Agent'] = @user_agent if @user_agent
  end

  def resolve(uri, referer = current_page)
    referer_uri = referer && referer.uri
    if uri.is_a?(URI)
      uri = uri.dup
    elsif uri.nil?
      if referer_uri
        return referer_uri
      end
      raise ArgumentError, "absolute URL needed (not nil)"
    else
      url = uri.to_s.strip
      if url.empty?
        if referer_uri
          return referer_uri.dup.tap { |u| u.fragment = nil }
        end
        raise ArgumentError, "absolute URL needed (not #{uri.inspect})"
      end

      url.gsub!(/[^#{0.chr}-#{126.chr}]/o) { |match|
        Mechanize::Util.uri_escape(match)
      }

      escaped_url = Mechanize::Util.html_unescape(
        url.split(/((?:%[0-9A-Fa-f]{2})+|#)/).each_slice(2).map { |x, y|
          "#{WEBrick::HTTPUtils.escape(x)}#{y}"
        }.join('')
      )

      begin
        uri = URI.parse(escaped_url)
      rescue
        uri = URI.parse(WEBrick::HTTPUtils.escape(escaped_url))
      end
    end

    uri.host = referer_uri.host if referer_uri && URI::HTTP === uri && uri.host.nil?

    scheme = uri.relative? ? 'relative' : uri.scheme.downcase
    uri = @scheme_handlers[scheme].call(uri, referer)

    if uri.relative?
      raise ArgumentError, "absolute URL needed (not #{uri})" unless
        referer_uri

      if referer.respond_to?(:bases) && referer.parser &&
          (lbase = referer.bases.last) && lbase.uri && lbase.uri.absolute?
        base = lbase
      else
        base = nil
      end

      base = referer_uri + (base ? base.uri : referer_uri)

      # Workaround for URI's bug in that it squashes consecutive
      # slashes.  See #304.
      if uri.path.match(%r{\A(.*?/)(?!/\.\.?(?!/))(/.*)\z}i)
        uri = URI((base + $1).to_s + $2)
      else
        uri = base + uri
      end

      # Strip initial "/.." bits from the path
      uri.path.sub!(/^(\/\.\.)+(?=\/)/, '')
    end

    unless ['http', 'https', 'file'].include?(uri.scheme.downcase)
      raise ArgumentError, "unsupported scheme: #{uri.scheme}"
    end

    case uri.path
    when nil
      raise ArgumentError, "hierarchical URL needed (not #{uri})"
    when ''.freeze
      uri.path = '/'
    end

    uri
  end

  def secure_resolve!(uri, referer = current_page)
    new_uri = resolve(uri, referer)

    if (referer_uri = referer && referer.uri) &&
       referer_uri.scheme != 'file'.freeze &&
       new_uri.scheme == 'file'.freeze
      raise Mechanize::Error, "insecure redirect to a file URI"
    end

    new_uri
  end

  def resolve_parameters uri, method, parameters
    case method
    when :head, :get, :delete, :trace then
      if parameters and parameters.length > 0
        uri.query ||= ''
        uri.query << '&' if uri.query.length > 0
        uri.query << Mechanize::Util.build_query_string(parameters)
      end

      return uri, nil
    end

    return uri, parameters
  end

  # :section: Response

  def get_meta_refresh response, uri, page
    return nil unless @follow_meta_refresh

    if page.respond_to?(:meta_refresh) and
       (redirect = page.meta_refresh.first) then
      [redirect.delay, redirect.href] unless
        not @follow_meta_refresh_self and redirect.link_self
    elsif refresh = response['refresh']
      delay, href, link_self = Mechanize::Page::MetaRefresh.parse refresh, uri
      raise Mechanize::Error, 'Invalid refresh http header' unless delay
      [delay.to_f, href] unless
        not @follow_meta_refresh_self and link_self
    end
  end

  def response_authenticate(response, page, uri, request, headers, params,
                            referer)
    www_authenticate = response['www-authenticate']

    unless www_authenticate = response['www-authenticate'] then
      message = 'WWW-Authenticate header missing in response'
      raise Mechanize::UnauthorizedError.new(page, nil, message)
    end

    challenges = @authenticate_parser.parse www_authenticate

    unless @auth_store.credentials? uri, challenges then
      message = "no credentials found, provide some with #add_auth"
      raise Mechanize::UnauthorizedError.new(page, challenges, message)
    end

    if challenge = challenges.find { |c| c.scheme =~ /^Digest$/i } then
      realm = challenge.realm uri

      auth_scheme = if response['server'] =~ /Microsoft-IIS/ then
                      :iis_digest
                    else
                      :digest
                    end

      existing_realms = @authenticate_methods[realm.uri][auth_scheme]

      if existing_realms.include? realm
        message = 'Digest authentication failed'
        raise Mechanize::UnauthorizedError.new(page, challenges, message)
      end

      existing_realms << realm
      @digest_challenges[realm] = challenge
    elsif challenge = challenges.find { |c| c.scheme == 'NTLM' } then
      existing_realms = @authenticate_methods[uri + '/'][:ntlm]

      if existing_realms.include?(realm) and not challenge.params then
        message = 'NTLM authentication failed'
        raise Mechanize::UnauthorizedError.new(page, challenges, message)
      end

      existing_realms << realm

      if challenge.params then
        type_2 = Net::NTLM::Message.decode64 challenge.params

        user, password, domain = @auth_store.credentials_for uri, nil

        type_3 = type_2.response({ :user => user, :password => password,
                                   :domain => domain },
                                 { :ntlmv2 => true }).encode64

        headers['Authorization'] = "NTLM #{type_3}"
      else
        type_1 = Net::NTLM::Message::Type1.new.encode64
        headers['Authorization'] = "NTLM #{type_1}"
      end
    elsif challenge = challenges.find { |c| c.scheme == 'Basic' } then
      realm = challenge.realm uri

      existing_realms = @authenticate_methods[realm.uri][:basic]

      if existing_realms.include? realm then
        message = 'Basic authentication failed'
        raise Mechanize::UnauthorizedError.new(page, challenges, message)
      end

      existing_realms << realm
    else
      message = 'unsupported authentication scheme'
      raise Mechanize::UnauthorizedError.new(page, challenges, message)
    end

    fetch uri, request.method.downcase.to_sym, headers, params, referer
  end

  def response_content_encoding response, body_io
    length = response.content_length ||
      case body_io
      when Tempfile, IO then
        body_io.stat.size
      else
        body_io.length
      end

    return body_io if length.zero?

    out_io = case response['Content-Encoding']
             when nil, 'none', '7bit', 'identity', "" then
               body_io
             when 'deflate' then
               content_encoding_inflate body_io
             when 'gzip', 'x-gzip' then
               content_encoding_gunzip body_io
             else
               raise Mechanize::Error,
                 "unsupported content-encoding: #{response['Content-Encoding']}"
             end

    out_io.flush
    out_io.rewind

    out_io
  rescue Zlib::Error => e
    message = "error handling content-encoding #{response['Content-Encoding']}:"
    message << " #{e.message} (#{e.class})"
    raise Mechanize::Error, message
  ensure
    begin
      if Tempfile === body_io and
         (StringIO === out_io or (out_io and out_io.path != body_io.path)) then
        body_io.close!
      end
    rescue IOError
      # HACK ruby 1.8 raises IOError when closing the stream
    end
  end

  def response_cookies response, uri, page
    if Mechanize::Page === page and page.body =~ /Set-Cookie/n
      page.search('//head/meta[@http-equiv="Set-Cookie"]').each do |meta|
        save_cookies(uri, meta['content'])
      end
    end

    header_cookies = response.get_fields 'Set-Cookie'

    return unless header_cookies

    header_cookies.each do |set_cookie|
      save_cookies(uri, set_cookie)
    end
  end

  def save_cookies(uri, set_cookie)
    return [] if set_cookie.nil?
    if log = log()	 # reduce method calls
      @cookie_jar.parse(set_cookie, uri, :logger => log) { |c|
        log.debug("saved cookie: #{c}")
        true
      }
    else
      @cookie_jar.parse(set_cookie, uri)
    end
  end

  def response_follow_meta_refresh response, uri, page, redirects
    delay, new_url = get_meta_refresh(response, uri, page)
    return nil unless delay
    new_url = new_url ? secure_resolve!(new_url, page) : uri

    raise Mechanize::RedirectLimitReachedError.new(page, redirects) if
      redirects + 1 > @redirection_limit

    sleep delay
    @history.push(page, page.uri)
    fetch new_url, :get, {}, [],
          Mechanize::Page.new, redirects + 1
  end

  def response_log response
    return unless log

    log.info("status: #{response.class} #{response.http_version} " \
             "#{response.code} #{response.message}")

    response.each_header do |k, v|
      log.debug("response-header: #{k} => #{v}")
    end
  end

  def response_parse response, body_io, uri
    @context.parse uri, response, body_io
  end

  def response_read response, request, uri
    content_length = response.content_length

    if use_tempfile? content_length then
      body_io = make_tempfile 'mechanize-raw'
    else
      body_io = StringIO.new.set_encoding(Encoding::BINARY)
    end

    total = 0

    begin
      response.read_body { |part|
        total += part.length

        if StringIO === body_io and use_tempfile? total then
          new_io = make_tempfile 'mechanize-raw'

          new_io.write body_io.string

          body_io = new_io
        end

        body_io.write(part)
        log.debug("Read #{part.length} bytes (#{total} total)") if log
      }
    rescue EOFError => e
      # terminating CRLF might be missing, let the user check the document
      raise unless response.chunked? and total.nonzero?

      body_io.rewind
      raise Mechanize::ChunkedTerminationError.new(e, response, body_io, uri,
                                                   @context)
    rescue Net::HTTP::Persistent::Error, Errno::ECONNRESET => e
      body_io.rewind
      raise Mechanize::ResponseReadError.new(e, response, body_io, uri,
                                             @context)
    end

    body_io.flush
    body_io.rewind

    raise Mechanize::ResponseCodeError.new(response, uri) if
      Net::HTTPUnknownResponse === response

    content_length = response.content_length

    unless Net::HTTP::Head === request or Net::HTTPRedirection === response then
      if content_length and content_length != body_io.length
        err = EOFError.new("Content-Length (#{content_length}) does not " \
                      "match response body length (#{body_io.length})")
        raise Mechanize::ResponseReadError.new(err, response, body_io, uri,
                                                @context)
      end
    end

    body_io
  end

  def response_redirect(response, method, page, redirects, headers,
                        referer = current_page)
    case @redirect_ok
    when true, :all
      # shortcut
    when false, nil
      return page
    when :permanent
      return page unless Net::HTTPMovedPermanently === response
    end

    log.info("follow redirect to: #{response['Location']}") if log

    raise Mechanize::RedirectLimitReachedError.new(page, redirects) if
      redirects + 1 > @redirection_limit

    redirect_method = method == :head ? :head : :get

    # Make sure we are not copying over the POST headers from the original request
    ['Content-Length', 'Content-MD5', 'Content-Type'].each do |key|
      headers.delete key
    end

    new_uri = secure_resolve! response['Location'].to_s, page

    @history.push(page, page.uri)

    fetch new_uri, redirect_method, headers, [], referer, redirects + 1
  end

  # :section: Robots

  RobotsKey = :__mechanize_get_robots__

  def get_robots(uri) # :nodoc:
    robots_mutex.synchronize do
      Thread.current[RobotsKey] = true
      begin
        fetch(uri).body
      rescue Mechanize::ResponseCodeError => e
        case e.response_code
        when /\A4\d\d\z/
          ''
        else
          raise e
        end
      rescue Mechanize::RedirectLimitReachedError
        ''
      ensure
        Thread.current[RobotsKey] = false
      end
    end
  end

  def robots= value
    require 'webrobots' if value
    @webrobots = nil if value != @robots
    @robots = value
  end

  ##
  # Tests if this agent is allowed to access +url+, consulting the site's
  # robots.txt.

  def robots_allowed? uri
    return true if Thread.current[RobotsKey]

    webrobots.allowed? uri
  end

  # Opposite of robots_allowed?

  def robots_disallowed? url
    !robots_allowed? url
  end

  # Returns an error object if there is an error in fetching or parsing
  # robots.txt of the site +url+.
  def robots_error(url)
    webrobots.error(url)
  end

  # Raises the error if there is an error in fetching or parsing robots.txt of
  # the site +url+.
  def robots_error!(url)
    webrobots.error!(url)
  end

  # Removes robots.txt cache for the site +url+.
  def robots_reset(url)
    webrobots.reset(url)
  end

  def webrobots
    @webrobots ||= WebRobots.new(@user_agent, :http_get => method(:get_robots))
  end

  # :section: SSL

  # Path to an OpenSSL CA certificate file
  def ca_file
    @http.ca_file
  end

  # Sets the path to an OpenSSL CA certificate file
  def ca_file= ca_file
    @http.ca_file = ca_file
  end

  # The SSL certificate store used for validating connections
  def cert_store
    @http.cert_store
  end

  # Sets the SSL certificate store used for validating connections
  def cert_store= cert_store
    @http.cert_store = cert_store
  end

  # The client X509 certificate
  def certificate
    @http.certificate
  end

  # Sets the client certificate to given X509 certificate.  If a path is given
  # the certificate will be loaded and set.
  def certificate= certificate
    certificate = if OpenSSL::X509::Certificate === certificate then
                    certificate
                  else
                    OpenSSL::X509::Certificate.new File.read certificate
                  end

    @http.certificate = certificate
  end

  # An OpenSSL private key or the path to a private key
  def private_key
    @http.private_key
  end

  # Sets the client's private key
  def private_key= private_key
    private_key = if OpenSSL::PKey::PKey === private_key then
                    private_key
                  else
                    OpenSSL::PKey::RSA.new File.read(private_key), @pass
                  end

    @http.private_key = private_key
  end

  # SSL version to use
  def ssl_version
    @http.ssl_version
  end

  # Sets the SSL version to use
  def ssl_version= ssl_version
    @http.ssl_version = ssl_version
  end

  # A callback for additional certificate verification.  See
  # OpenSSL::SSL::SSLContext#verify_callback
  #
  # The callback can be used for debugging or to ignore errors by always
  # returning +true+.  Specifying nil uses the default method that was valid
  # when the SSLContext was created
  def verify_callback
    @http.verify_callback
  end

  # Sets the certificate verify callback
  def verify_callback= verify_callback
    @http.verify_callback = verify_callback
  end

  # How to verify SSL connections.  Defaults to VERIFY_PEER
  def verify_mode
    @http.verify_mode
  end

  # Sets the mode for verifying SSL connections
  def verify_mode= verify_mode
    @http.verify_mode = verify_mode
  end

  # :section: Timeouts

  # Reset connections that have not been used in this many seconds
  def idle_timeout
    @http.idle_timeout
  end

  # Sets the connection idle timeout for persistent connections
  def idle_timeout= timeout
    @http.idle_timeout = timeout
  end

  # :section: Utility

  ##
  # Creates a new output IO by reading +input_io+ in +read_size+ chunks.  If
  # the output is over the max_file_buffer size a Tempfile with +name+ is
  # created.
  #
  # If a block is provided, each chunk of +input_io+ is yielded for further
  # processing.

  def auto_io name, read_size, input_io
    out_io = StringIO.new.set_encoding(Encoding::BINARY)

    until input_io.eof? do
      if StringIO === out_io and use_tempfile? out_io.size then
        new_io = make_tempfile name
        new_io.write out_io.string
        out_io = new_io
      end

      chunk = input_io.read read_size
      chunk = yield chunk if block_given?

      out_io.write chunk
    end

    out_io.rewind

    out_io
  end

  def inflate compressed, window_bits = nil
    inflate = Zlib::Inflate.new window_bits

    out_io = auto_io 'mechanize-inflate', 1024, compressed do |chunk|
      inflate.inflate chunk
    end

    inflate.finish

    out_io
  ensure
    inflate.close if inflate.finished?
  end

  def log
    @context.log
  end

  ##
  # Sets the proxy address, port, user, and password. +addr+ may be
  # an HTTP URL/URI or a host name, +port+ may be a port number, service
  # name or port number string.

  def set_proxy addr, port = nil, user = nil, pass = nil
    case addr
    when URI::HTTP
      proxy_uri = addr.dup
    when %r{\Ahttps?://}i
      proxy_uri = URI addr
    when String
      proxy_uri = URI "http://#{addr}"
    when nil
      @http.proxy = nil
      return
    end

    case port
    when Integer
      proxy_uri.port = port
    when nil
    else
      begin
        proxy_uri.port = Socket.getservbyname port
      rescue SocketError
        begin
          proxy_uri.port = Integer port
        rescue ArgumentError
          raise ArgumentError, "invalid value for port: #{port.inspect}"
        end
      end
    end

    proxy_uri.user     = user if user
    proxy_uri.password = pass if pass

    @http.proxy = proxy_uri
  end

  def make_tempfile name
    io = Tempfile.new name
    io.unlink
    io.binmode
    io
  end

  def use_tempfile? size
    return false unless @max_file_buffer
    return false unless size

    size >= @max_file_buffer
  end

  def reset
    @cookie_jar.clear
    @history.clear
  end

end

require 'mechanize/http/auth_store'

