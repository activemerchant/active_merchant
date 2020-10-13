require 'mechanize/version'
require 'fileutils'
require 'forwardable'
require 'mutex_m'
require 'net/http/digest_auth'
require 'net/http/persistent'
require 'nokogiri'
require 'openssl'
require 'pp'
require 'stringio'
require 'uri'
require 'webrick/httputils'
require 'zlib'

##
# The Mechanize library is used for automating interactions with a website.  It
# can follow links and submit forms.  Form fields can be populated and
# submitted.  A history of URLs is maintained and can be queried.
#
# == Example
#
#   require 'mechanize'
#   require 'logger'
#
#   agent = Mechanize.new
#   agent.log = Logger.new "mech.log"
#   agent.user_agent_alias = 'Mac Safari'
#
#   page = agent.get "http://www.google.com/"
#   search_form = page.form_with :name => "f"
#   search_form.field_with(:name => "q").value = "Hello"
#
#   search_results = agent.submit search_form
#   puts search_results.body
#
# == Issues with mechanize
#
# If you think you have a bug with mechanize, but aren't sure, please file a
# ticket at https://github.com/sparklemotion/mechanize/issues
#
# Here are some common problems you may experience with mechanize
#
# === Problems connecting to SSL sites
#
# Mechanize defaults to validating SSL certificates using the default CA
# certificates for your platform.  At this time, Windows users do not have
# integration between the OS default CA certificates and OpenSSL.  #cert_store
# explains how to download and use Mozilla's CA certificates to allow SSL
# sites to work.
#
# === Problems with content-length
#
# Some sites return an incorrect content-length value.  Unlike a browser,
# mechanize raises an error when the content-length header does not match the
# response length since it does not know if there was a connection problem or
# if the mismatch is a server bug.
#
# The error raised, Mechanize::ResponseReadError, can be converted to a parsed
# Page, File, etc. depending upon the content-type:
#
#   agent = Mechanize.new
#   uri = URI 'http://example/invalid_content_length'
#
#   begin
#     page = agent.get uri
#   rescue Mechanize::ResponseReadError => e
#     page = e.force_parse
#   end

class Mechanize

  ##
  # Base mechanize error class

  class Error < RuntimeError
  end

  ruby_version = if RUBY_PATCHLEVEL >= 0 then
                   "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
                 else
                   "#{RUBY_VERSION}dev#{RUBY_REVISION}"
                 end

  ##
  # Supported User-Agent aliases for use with user_agent_alias=.  The
  # description in parenthesis is for informative purposes and is not part of
  # the alias name.
  #
  # * Linux Firefox (43.0 on Ubuntu Linux)
  # * Linux Konqueror (3)
  # * Linux Mozilla
  # * Mac Firefox (43.0)
  # * Mac Mozilla
  # * Mac Safari (9.0 on OS X 10.11.2)
  # * Mac Safari 4
  # * Mechanize (default)
  # * Windows IE 6
  # * Windows IE 7
  # * Windows IE 8
  # * Windows IE 9
  # * Windows IE 10 (Windows 8 64bit)
  # * Windows IE 11 (Windows 8.1 64bit)
  # * Windows Edge
  # * Windows Mozilla
  # * Windows Firefox (43.0)
  # * iPhone (iOS 9.1)
  # * iPad (iOS 9.1)
  # * Android (5.1.1)
  #
  # Example:
  #
  #   agent = Mechanize.new
  #   agent.user_agent_alias = 'Mac Safari'

  AGENT_ALIASES = {
    'Mechanize' => "Mechanize/#{VERSION} Ruby/#{ruby_version} (http://github.com/sparklemotion/mechanize/)",
    'Linux Firefox' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0',
    'Linux Konqueror' => 'Mozilla/5.0 (compatible; Konqueror/3; Linux)',
    'Linux Mozilla' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624',
    'Mac Firefox' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.11; rv:43.0) Gecko/20100101 Firefox/43.0',
    'Mac Mozilla' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401',
    'Mac Safari 4' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_2; de-at) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10',
    'Mac Safari' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_2) AppleWebKit/601.3.9 (KHTML, like Gecko) Version/9.0.2 Safari/601.3.9',
    'Windows Chrome' => 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.125 Safari/537.36',
    'Windows IE 6' => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
    'Windows IE 7' => 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)',
    'Windows IE 8' => 'Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.50727)',
    'Windows IE 9' => 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)',
    'Windows IE 10' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)',
    'Windows IE 11' => 'Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; rv:11.0) like Gecko',
    'Windows Edge' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.10586',
    'Windows Mozilla' => 'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6',
    'Windows Firefox' => 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:43.0) Gecko/20100101 Firefox/43.0',
    'iPhone' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B5110e Safari/601.1',
    'iPad' => 'Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1',
    'Android' => 'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 7 Build/LMY47V) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.76 Safari/537.36',
  }

  AGENT_ALIASES.default_proc = proc { |hash, key|
    case key
    when /FireFox/
      if ua = hash[nkey = key.sub(/FireFox/, 'Firefox')]
        warn "Mechanize#user_agent_alias: #{key.inspect} should be spelled as #{nkey.inspect}"
        ua
      end
    end
  }

  def self.inherited(child) # :nodoc:
    child.html_parser = html_parser
    child.log = log
    super
  end

  ##
  # Creates a new Mechanize instance and yields it to the given block.
  #
  # After the block executes, the instance is cleaned up. This includes
  # closing all open connections.
  #
  #   Mechanize.start do |m|
  #     m.get("http://example.com")
  #   end

  def self.start
    instance = new
    yield(instance)
  ensure
    instance.shutdown
  end

  ##
  # Creates a new mechanize instance.  If a block is given, the created
  # instance is yielded to the block for setting up pre-connection state such
  # as SSL parameters or proxies:
  #
  #   agent = Mechanize.new do |a|
  #     a.proxy_host = 'proxy.example'
  #     a.proxy_port = 8080
  #   end
  #
  # If you need segregated SSL connections give each agent a unique
  # name.  Otherwise the connections will be shared.  This is
  # particularly important if you are using certifcates.
  #
  #    agent_1 = Mechanize.new 'conn1'
  #    agent_2 = Mechanize.new 'conn2'
  #

  def initialize(connection_name = 'mechanize')
    @agent = Mechanize::HTTP::Agent.new(connection_name)
    @agent.context = self
    @log = nil

    # attr_accessors
    @agent.user_agent = AGENT_ALIASES['Mechanize']
    @watch_for_set    = nil
    @history_added    = nil

    # attr_readers
    @pluggable_parser = PluggableParser.new

    @keep_alive_time  = 0

    # Proxy
    @proxy_addr = nil
    @proxy_port = nil
    @proxy_user = nil
    @proxy_pass = nil

    @html_parser = self.class.html_parser

    @default_encoding = nil
    @force_default_encoding = false

    # defaults
    @agent.max_history = 50

    yield self if block_given?

    @agent.set_proxy @proxy_addr, @proxy_port, @proxy_user, @proxy_pass
  end

  # :section: History
  #
  # Methods for navigating and controlling history

  ##
  # Equivalent to the browser back button.  Returns the previous page visited.

  def back
    @agent.history.pop
  end

  ##
  # Returns the latest page loaded by Mechanize

  def current_page
    @agent.current_page
  end

  alias page current_page

  ##
  # The history of this mechanize run

  def history
    @agent.history
  end

  ##
  # Maximum number of items allowed in the history.  The default setting is 50
  # pages.  Note that the size of the history multiplied by the maximum
  # response body size

  def max_history
    @agent.history.max_size
  end

  ##
  # Sets the maximum number of items allowed in the history to +length+.
  #
  # Setting the maximum history length to nil will make the history size
  # unlimited.  Take care when doing this, mechanize stores response bodies in
  # memory for pages and in the temporary files directory for other responses.
  # For a long-running mechanize program this can be quite large.
  #
  # See also the discussion under #max_file_buffer=

  def max_history= length
    @agent.history.max_size = length
  end

  ##
  # Returns a visited page for the +url+ passed in, otherwise nil

  def visited? url
    url = url.href if url.respond_to? :href

    @agent.visited_page url
  end

  ##
  # Returns whether or not a url has been visited

  alias visited_page visited?

  # :section: Hooks
  #
  # Hooks into the operation of mechanize

  ##
  # A list of hooks to call before reading response header 'content-encoding'.
  #
  # The hook is called with the agent making the request, the URI of the
  # request, the response an IO containing the response body.

  def content_encoding_hooks
    @agent.content_encoding_hooks
  end

  ##
  # Callback which is invoked with the page that was added to history.

  attr_accessor :history_added

  ##
  # A list of hooks to call after retrieving a response. Hooks are called with
  # the agent, the URI, the response, and the response body.

  def post_connect_hooks
    @agent.post_connect_hooks
  end

  ##
  # A list of hooks to call before retrieving a response. Hooks are called
  # with the agent, the URI, the response, and the response body.

  def pre_connect_hooks
    @agent.pre_connect_hooks
  end

  # :section: Requests
  #
  # Methods for making HTTP requests

  ##
  # If the parameter is a string, finds the button or link with the
  # value of the string on the current page and clicks it.  Otherwise, clicks
  # the Mechanize::Page::Link object passed in.  Returns the page fetched.

  def click link
    case link
    when Page::Link then
      referer = link.page || current_page()
      if @agent.robots
        if (referer.is_a?(Page) and referer.parser.nofollow?) or
           link.rel?('nofollow') then
          raise RobotsDisallowedError.new(link.href)
        end
      end
      if link.noreferrer?
        href = @agent.resolve(link.href, link.page || current_page)
        referer = Page.new
      else
        href = link.href
      end
      get href, [], referer
    when String, Regexp then
      if real_link = page.link_with(:text => link)
        click real_link
      else
        button = nil
        # Note that this will not work if we have since navigated to a different page.
        # Should rather make each button aware of its parent form.
        form = page.forms.find do |f|
          button = f.button_with(:value => link)
          button.is_a? Form::Submit
        end
        submit form, button if form
      end
    when Form::Submit, Form::ImageButton then
      # Note that this will not work if we have since navigated to a different page.
      # Should rather make each button aware of its parent form.
      form = page.forms.find do |f|
        f.buttons.include?(link)
      end
      submit form, link if form
    else
      referer = current_page()
      href = link.respond_to?(:href) ? link.href :
        (link['href'] || link['src'])
      get href, [], referer
    end
  end

  ##
  # GETs +uri+ and writes it to +io_or_filename+ without recording the request
  # in the history.  If +io_or_filename+ does not respond to #write it will be
  # used as a file name.  +parameters+, +referer+ and +headers+ are used as in
  # #get.
  #
  # By default, if the Content-type of the response matches a Mechanize::File
  # or Mechanize::Page parser, the response body will be loaded into memory
  # before being saved.  See #pluggable_parser for details on changing this
  # default.
  #
  # For alternate ways of downloading files see Mechanize::FileSaver and
  # Mechanize::DirectorySaver.

  def download uri, io_or_filename, parameters = [], referer = nil, headers = {}
    page = transact do
      get uri, parameters, referer, headers
    end

    io = if io_or_filename.respond_to? :write then
           io_or_filename
         else
           open io_or_filename, 'wb'
         end

    case page
    when Mechanize::File then
      io.write page.body
    else
      body_io = page.body_io

      until body_io.eof? do
        io.write body_io.read 16384
      end
    end

    page
  ensure
    io.close if io and not io_or_filename.respond_to? :write
  end

  ##
  # DELETE +uri+ with +query_params+, and setting +headers+:
  #
  # +query_params+ is formatted into a query string using
  # Mechanize::Util.build_query_string, which see.
  #
  #   delete('http://example/', {'q' => 'foo'}, {})

  def delete(uri, query_params = {}, headers = {})
    page = @agent.fetch(uri, :delete, headers, query_params)
    add_to_history(page)
    page
  end

  ##
  # GET the +uri+ with the given request +parameters+, +referer+ and
  # +headers+.
  #
  # The +referer+ may be a URI or a page.
  #
  # +parameters+ is formatted into a query string using
  # Mechanize::Util.build_query_string, which see.

  def get(uri, parameters = [], referer = nil, headers = {})
    method = :get

    referer ||=
      if uri.to_s =~ %r{\Ahttps?://}
        Page.new
      else
        current_page || Page.new
      end

    # FIXME: Huge hack so that using a URI as a referer works.  I need to
    # refactor everything to pass around URIs but still support
    # Mechanize::Page#base
    unless Mechanize::Parser === referer then
      referer = if referer.is_a?(String) then
                  Page.new URI(referer)
                else
                  Page.new referer
                end
    end

    # fetch the page
    headers ||= {}
    page = @agent.fetch uri, method, headers, parameters, referer
    add_to_history(page)
    yield page if block_given?
    page
  end

  ##
  # GET +url+ and return only its contents

  def get_file(url)
    get(url).body
  end

  ##
  # HEAD +uri+ with +query_params+ and +headers+:
  #
  # +query_params+ is formatted into a query string using
  # Mechanize::Util.build_query_string, which see.
  #
  #   head('http://example/', {'q' => 'foo'}, {})

  def head(uri, query_params = {}, headers = {})
    page = @agent.fetch uri, :head, headers, query_params

    yield page if block_given?

    page
  end

  ##
  # POST to the given +uri+ with the given +query+.
  #
  # +query+ is processed using Mechanize::Util.each_parameter (which
  # see), and then encoded into an entity body.  If any IO/FileUpload
  # object is specified as a field value the "enctype" will be
  # multipart/form-data, or application/x-www-form-urlencoded
  # otherwise.
  #
  # Examples:
  #   agent.post 'http://example.com/', "foo" => "bar"
  #
  #   agent.post 'http://example.com/', [%w[foo bar]]
  #
  #   agent.post('http://example.com/', "<message>hello</message>",
  #              'Content-Type' => 'application/xml')

  def post(uri, query = {}, headers = {})
    return request_with_entity(:post, uri, query, headers) if String === query

    node = {}
    # Create a fake form
    class << node
      def search(*args); []; end
    end
    node['method'] = 'POST'
    node['enctype'] = 'application/x-www-form-urlencoded'

    form = Form.new(node)

    Mechanize::Util.each_parameter(query) { |k, v|
      if v.is_a?(IO)
        form.enctype = 'multipart/form-data'
        ul = Form::FileUpload.new({'name' => k.to_s},::File.basename(v.path))
        ul.file_data = v.read
        form.file_uploads << ul
      elsif v.is_a?(Form::FileUpload)
        form.enctype = 'multipart/form-data'
        form.file_uploads << v
      else
        form.fields << Form::Field.new({'name' => k.to_s},v)
      end
    }
    post_form(uri, form, headers)
  end

  ##
  # PUT to +uri+ with +entity+, and setting +headers+:
  #
  #   put('http://example/', 'new content', {'Content-Type' => 'text/plain'})

  def put(uri, entity, headers = {})
    request_with_entity(:put, uri, entity, headers)
  end

  ##
  # Makes an HTTP request to +url+ using HTTP method +verb+.  +entity+ is used
  # as the request body, if allowed.

  def request_with_entity(verb, uri, entity, headers = {})
    cur_page = current_page || Page.new

    log.debug("query: #{ entity.inspect }") if log

    headers = {
      'Content-Type' => 'application/octet-stream',
      'Content-Length' => entity.size.to_s,
    }.update headers

    page = @agent.fetch uri, verb, headers, [entity], cur_page
    add_to_history(page)
    page
  end

  ##
  # Submits +form+ with an optional +button+.
  #
  # Without a button:
  #
  #   page = agent.get('http://example.com')
  #   agent.submit(page.forms.first)
  #
  # With a button:
  #
  #   agent.submit(page.forms.first, page.forms.first.buttons.first)

  def submit(form, button = nil, headers = {})
    form.add_button_to_query(button) if button

    case form.method.upcase
    when 'POST'
      post_form(form.action, form, headers)
    when 'GET'
      get(form.action.gsub(/\?[^\?]*$/, ''),
          form.build_query,
          form.page,
          headers)
    else
      raise ArgumentError, "unsupported method: #{form.method.upcase}"
    end
  end

  ##
  # Runs given block, then resets the page history as it was before. self is
  # given as a parameter to the block.  Returns the value of the block.

  def transact
    history_backup = @agent.history.dup
    begin
      yield self
    ensure
      @agent.history = history_backup
    end
  end

  # :section: Settings
  #
  # Settings that adjust how mechanize makes HTTP requests including timeouts,
  # keep-alives, compression, redirects and headers.

  @html_parser = Nokogiri::HTML
  @log = nil

  class << self

    ##
    # Default HTML parser for all mechanize instances
    #
    #   Mechanize.html_parser = Nokogiri::XML

    attr_accessor :html_parser

    ##
    # Default logger for all mechanize instances
    #
    #   Mechanize.log = Logger.new $stderr

    attr_accessor :log

  end

  ##
  # A default encoding name used when parsing HTML parsing.  When set it is
  # used after any other encoding.  The default is nil.

  attr_accessor :default_encoding

  ##
  # Overrides the encodings given by the HTTP server and the HTML page with
  # the default_encoding when set to true.

  attr_accessor :force_default_encoding

  ##
  # The HTML parser to be used when parsing documents

  attr_accessor :html_parser

  ##
  # HTTP/1.0 keep-alive time.  This is no longer supported by mechanize as it
  # now uses net-http-persistent which only supports HTTP/1.1 persistent
  # connections

  attr_accessor :keep_alive_time

  ##
  # The pluggable parser maps a response Content-Type to a parser class.  The
  # registered Content-Type may be either a full content type like 'image/png'
  # or a media type 'text'.  See Mechanize::PluggableParser for further
  # details.
  #
  # Example:
  #
  #   agent.pluggable_parser['application/octet-stream'] = Mechanize::Download

  attr_reader :pluggable_parser

  ##
  # The HTTP proxy address

  attr_reader :proxy_addr

  ##
  # The HTTP proxy password

  attr_reader :proxy_pass

  ##
  # The HTTP proxy port

  attr_reader :proxy_port

  ##
  # The HTTP proxy username

  attr_reader :proxy_user

  ##
  # *NOTE*: These credentials will be used as a default for any challenge
  # exposing your password to disclosure to malicious servers.  Use of this
  # method will warn.  This method is deprecated and will be removed in
  # mechanize 3.
  #
  # Sets the +user+ and +password+ as the default credentials to be used for
  # HTTP authentication for any server.  The +domain+ is used for NTLM
  # authentication.

  def auth user, password, domain = nil
    caller.first =~ /(.*?):(\d+).*?$/

    warn <<-WARNING
At #{$1} line #{$2}

Use of #auth and #basic_auth are deprecated due to a security vulnerability.

    WARNING

    @agent.add_default_auth user, password, domain
  end

  alias basic_auth auth

  ##
  # Adds credentials +user+, +pass+ for +uri+.  If +realm+ is set the
  # credentials are used only for that realm.  If +realm+ is not set the
  # credentials become the default for any realm on that URI.
  #
  # +domain+ and +realm+ are exclusive as NTLM does not follow RFC 2617.  If
  # +domain+ is given it is only used for NTLM authentication.

  def add_auth uri, user, password, realm = nil, domain = nil
    @agent.add_auth uri, user, password, realm, domain
  end

  ##
  # Are If-Modified-Since conditional requests enabled?

  def conditional_requests
    @agent.conditional_requests
  end

  ##
  # Disables If-Modified-Since conditional requests (enabled by default)

  def conditional_requests= enabled
    @agent.conditional_requests = enabled
  end

  ##
  # A Mechanize::CookieJar which stores cookies

  def cookie_jar
    @agent.cookie_jar
  end

  ##
  # Replaces the cookie jar with +cookie_jar+

  def cookie_jar= cookie_jar
    @agent.cookie_jar = cookie_jar
  end

  ##
  # Returns a list of cookies stored in the cookie jar.

  def cookies
    @agent.cookie_jar.to_a
  end

  ##
  # Follow HTML meta refresh and HTTP Refresh headers.  If set to +:anywhere+
  # meta refresh tags outside of the head element will be followed.

  def follow_meta_refresh
    @agent.follow_meta_refresh
  end

  ##
  # Controls following of HTML meta refresh and HTTP Refresh headers in
  # responses.

  def follow_meta_refresh= follow
    @agent.follow_meta_refresh = follow
  end

  ##
  # Follow an HTML meta refresh and HTTP Refresh headers that have no "url="
  # in the content attribute.
  #
  # Defaults to false to prevent infinite refresh loops.

  def follow_meta_refresh_self
    @agent.follow_meta_refresh_self
  end

  ##
  # Alters the following of HTML meta refresh and HTTP Refresh headers that
  # point to the same page.

  def follow_meta_refresh_self= follow
    @agent.follow_meta_refresh_self = follow
  end

  ##
  # Is gzip compression of responses enabled?

  def gzip_enabled
    @agent.gzip_enabled
  end

  ##
  # Disables HTTP/1.1 gzip compression (enabled by default)

  def gzip_enabled=enabled
    @agent.gzip_enabled = enabled
  end

  ##
  # Connections that have not been used in this many seconds will be reset.

  def idle_timeout
    @agent.idle_timeout
  end

  # Sets the idle timeout to +idle_timeout+.  The default timeout is 5
  # seconds.  If you experience "too many connection resets", reducing this
  # value may help.

  def idle_timeout= idle_timeout
    @agent.idle_timeout = idle_timeout
  end

  ##
  # When set to true mechanize will ignore an EOF during chunked transfer
  # encoding so long as at least one byte was received.  Be careful when
  # enabling this as it may cause data loss.
  #
  # Net::HTTP does not inform mechanize of where in the chunked stream the EOF
  # occurred.  Usually it is after the last-chunk but before the terminating
  # CRLF (invalid termination) but it may occur earlier.  In the second case
  # your response body may be incomplete.

  def ignore_bad_chunking
    @agent.ignore_bad_chunking
  end

  ##
  # When set to true mechanize will ignore an EOF during chunked transfer
  # encoding.  See ignore_bad_chunking for further details

  def ignore_bad_chunking= ignore_bad_chunking
    @agent.ignore_bad_chunking = ignore_bad_chunking
  end

  ##
  # Are HTTP/1.1 keep-alive connections enabled?

  def keep_alive
    @agent.keep_alive
  end

  ##
  # Disable HTTP/1.1 keep-alive connections if +enable+ is set to false.  If
  # you are experiencing "too many connection resets" errors setting this to
  # false will eliminate them.
  #
  # You should first investigate reducing idle_timeout.

  def keep_alive= enable
    @agent.keep_alive = enable
  end

  ##
  # The current logger.  If no logger has been set Mechanize.log is used.

  def log
    @log || Mechanize.log
  end

  ##
  # Sets the +logger+ used by this instance of mechanize

  def log= logger
    @log = logger
  end

  ##
  # Responses larger than this will be written to a Tempfile instead of stored
  # in memory.  The default is 100,000 bytes.
  #
  # A value of nil disables creation of Tempfiles.

  def max_file_buffer
    @agent.max_file_buffer
  end

  ##
  # Sets the maximum size of a response body that will be stored in memory to
  # +bytes+.  A value of nil causes all response bodies to be stored in
  # memory.
  #
  # Note that for Mechanize::Download subclasses, the maximum buffer size
  # multiplied by the number of pages stored in history (controlled by
  # #max_history) is an approximate upper limit on the amount of memory
  # Mechanize will use.  By default, Mechanize can use up to ~5MB to store
  # response bodies for non-File and non-Page (HTML) responses.
  #
  # See also the discussion under #max_history=

  def max_file_buffer= bytes
    @agent.max_file_buffer = bytes
  end

  ##
  # Length of time to wait until a connection is opened in seconds

  def open_timeout
    @agent.open_timeout
  end

  ##
  # Sets the connection open timeout to +open_timeout+

  def open_timeout= open_timeout
    @agent.open_timeout = open_timeout
  end

  ##
  # Length of time to wait for data from the server

  def read_timeout
    @agent.read_timeout
  end

  ##
  # Sets the timeout for each chunk of data read from the server to
  # +read_timeout+.  A single request may read many chunks of data.

  def read_timeout= read_timeout
    @agent.read_timeout = read_timeout
  end

  ##
  # Controls how mechanize deals with redirects.  The following values are
  # allowed:
  #
  # :all, true:: All 3xx redirects are followed (default)
  # :permanent:: Only 301 Moved Permanantly redirects are followed
  # false:: No redirects are followed

  def redirect_ok
    @agent.redirect_ok
  end

  alias follow_redirect? redirect_ok

  ##
  # Sets the mechanize redirect handling policy.  See redirect_ok for allowed
  # values

  def redirect_ok= follow
    @agent.redirect_ok = follow
  end

  alias follow_redirect= redirect_ok=

  ##
  # Maximum number of redirections to follow

  def redirection_limit
    @agent.redirection_limit
  end

  ##
  # Sets the maximum number of redirections to follow to +limit+

  def redirection_limit= limit
    @agent.redirection_limit = limit
  end

  ##
  # Resolve the full path of a link / uri
  def resolve link
    @agent.resolve link
  end

  ##
  # A hash of custom request headers that will be sent on every request

  def request_headers
    @agent.request_headers
  end

  ##
  # Replaces the custom request headers that will be sent on every request
  # with +request_headers+

  def request_headers= request_headers
    @agent.request_headers = request_headers
  end

  ##
  # Retry POST and other non-idempotent requests.  See RFC 2616 9.1.2.

  def retry_change_requests
    @agent.retry_change_requests
  end

  ##
  # When setting +retry_change_requests+ to true you are stating that, for all
  # the URLs you access with mechanize, making POST and other non-idempotent
  # requests is safe and will not cause data duplication or other harmful
  # results.
  #
  # If you are experiencing "too many connection resets" errors you should
  # instead investigate reducing the idle_timeout or disabling keep_alive
  # connections.

  def retry_change_requests= retry_change_requests
    @agent.retry_change_requests = retry_change_requests
  end

  ##
  # Will <code>/robots.txt</code> files be obeyed?

  def robots
    @agent.robots
  end

  ##
  # When +enabled+ mechanize will retrieve and obey <code>robots.txt</code>
  # files

  def robots= enabled
    @agent.robots = enabled
  end

  ##
  # The handlers for HTTP and other URI protocols.

  def scheme_handlers
    @agent.scheme_handlers
  end

  ##
  # Replaces the URI scheme handler table with +scheme_handlers+

  def scheme_handlers= scheme_handlers
    @agent.scheme_handlers = scheme_handlers
  end

  ##
  # The identification string for the client initiating a web request

  def user_agent
    @agent.user_agent
  end

  ##
  # Sets the User-Agent used by mechanize to +user_agent+.  See also
  # user_agent_alias

  def user_agent= user_agent
    @agent.user_agent = user_agent
  end

  ##
  # Set the user agent for the Mechanize object based on the given +name+.
  #
  # See also AGENT_ALIASES

  def user_agent_alias= name
    self.user_agent = AGENT_ALIASES[name] ||
      raise(ArgumentError, "unknown agent alias #{name.inspect}")
  end

  ##
  # The value of watch_for_set is passed to pluggable parsers for retrieved
  # content

  attr_accessor :watch_for_set

  # :section: SSL
  #
  # SSL settings for mechanize.  These must be set in the block given to
  # Mechanize.new

  ##
  # Path to an OpenSSL server certificate file

  def ca_file
    @agent.ca_file
  end

  ##
  # Sets the certificate file used for SSL connections

  def ca_file= ca_file
    @agent.ca_file = ca_file
  end

  ##
  # An OpenSSL client certificate or the path to a certificate file.

  def cert
    @agent.certificate
  end

  ##
  # Sets the OpenSSL client certificate +cert+ to the given path or
  # certificate instance

  def cert= cert
    @agent.certificate = cert
  end

  ##
  # An OpenSSL certificate store for verifying server certificates.  This
  # defaults to the default certificate store for your system.
  #
  # If your system does not ship with a default set of certificates you can
  # retrieve a copy of the set from Mozilla here:
  # http://curl.haxx.se/docs/caextract.html
  #
  # (Note that this set does not have an HTTPS download option so you may
  # wish to use the firefox-db2pem.sh script to extract the certificates
  # from a local install to avoid man-in-the-middle attacks.)
  #
  # After downloading or generating a cacert.pem from the above link you
  # can create a certificate store from the pem file like this:
  #
  #   cert_store = OpenSSL::X509::Store.new
  #   cert_store.add_file 'cacert.pem'
  #
  # And have mechanize use it with:
  #
  #   agent.cert_store = cert_store

  def cert_store
    @agent.cert_store
  end

  ##
  # Sets the OpenSSL certificate store to +store+.
  #
  # See also #cert_store

  def cert_store= cert_store
    @agent.cert_store = cert_store
  end

  ##
  # What is this?
  #
  # Why is it different from #cert?

  def certificate # :nodoc:
    @agent.certificate
  end

  ##
  # An OpenSSL private key or the path to a private key

  def key
    @agent.private_key
  end

  ##
  # Sets the OpenSSL client +key+ to the given path or key instance.  If a
  # path is given, the path must contain an RSA key file.

  def key= key
    @agent.private_key = key
  end

  ##
  # OpenSSL client key password

  def pass
    @agent.pass
  end

  ##
  # Sets the client key password to +pass+

  def pass= pass
    @agent.pass = pass
  end

  ##
  # SSL version to use.

  def ssl_version
    @agent.ssl_version
  end

  ##
  # Sets the SSL version to use to +version+ without client/server
  # negotiation.

  def ssl_version= ssl_version
    @agent.ssl_version = ssl_version
  end

  ##
  # A callback for additional certificate verification.  See
  # OpenSSL::SSL::SSLContext#verify_callback
  #
  # The callback can be used for debugging or to ignore errors by always
  # returning +true+.  Specifying nil uses the default method that was valid
  # when the SSLContext was created

  def verify_callback
    @agent.verify_callback
  end

  ##
  # Sets the OpenSSL certificate verification callback

  def verify_callback= verify_callback
    @agent.verify_callback = verify_callback
  end

  ##
  # the OpenSSL server certificate verification method.  The default is
  # OpenSSL::SSL::VERIFY_PEER and certificate verification uses the default
  # system certificates.  See also cert_store

  def verify_mode
    @agent.verify_mode
  end

  ##
  # Sets the OpenSSL server certificate verification method.

  def verify_mode= verify_mode
    @agent.verify_mode = verify_mode
  end

  # :section: Utilities

  attr_reader :agent # :nodoc:

  ##
  # Parses the +body+ of the +response+ from +uri+ using the pluggable parser
  # that matches its content type

  def parse uri, response, body
    content_type = nil

    unless response['Content-Type'].nil?
      data, = response['Content-Type'].split ';', 2
      content_type, = data.downcase.split ',', 2 unless data.nil?
    end

    parser_klass = @pluggable_parser.parser content_type

    unless parser_klass <= Mechanize::Download then
      body = case body
             when IO, Tempfile, StringIO then
               body.read
             else
               body
             end
    end

    parser_klass.new uri, response, body, response.code do |parser|
      parser.mech = self if parser.respond_to? :mech=

      parser.watch_for_set = @watch_for_set if
        @watch_for_set and parser.respond_to?(:watch_for_set=)
    end
  end

  def pretty_print(q) # :nodoc:
    q.object_group(self) {
      q.breakable
      q.pp cookie_jar
      q.breakable
      q.pp current_page
    }
  end

  ##
  # Sets the proxy +address+ at +port+ with an optional +user+ and +password+

  def set_proxy address, port, user = nil, password = nil
    @proxy_addr = address
    @proxy_port = port
    @proxy_user = user
    @proxy_pass = password

    @agent.set_proxy address, port, user, password
  end

  ##
  # Clears history and cookies.

  def reset
    @agent.reset
  end

  ##
  # Shuts down this session by clearing browsing state and closing all
  # persistent connections.

  def shutdown
    reset
    @agent.shutdown
  end

  private

  ##
  # Posts +form+ to +uri+

  def post_form(uri, form, headers = {})
    cur_page = form.page || current_page ||
      Page.new

    request_data = form.request_data

    log.debug("query: #{ request_data.inspect }") if log

    headers = {
      'Content-Type'    => form.enctype,
      'Content-Length'  => request_data.size.to_s,
    }.merge headers

    # fetch the page
    page = @agent.fetch uri, :post, headers, [request_data], cur_page
    add_to_history(page)
    page
  end

  ##
  # Adds +page+ to the history

  def add_to_history(page)
    @agent.history.push(page, @agent.resolve(page.uri))
    @history_added.call(page) if @history_added
  end

end

require 'mechanize/element_not_found_error'
require 'mechanize/response_read_error'
require 'mechanize/chunked_termination_error'
require 'mechanize/content_type_error'
require 'mechanize/cookie'
require 'mechanize/cookie_jar'
require 'mechanize/parser'
require 'mechanize/download'
require 'mechanize/directory_saver'
require 'mechanize/file'
require 'mechanize/file_connection'
require 'mechanize/file_request'
require 'mechanize/file_response'
require 'mechanize/form'
require 'mechanize/history'
require 'mechanize/http'
require 'mechanize/http/agent'
require 'mechanize/http/auth_challenge'
require 'mechanize/http/auth_realm'
require 'mechanize/http/content_disposition_parser'
require 'mechanize/http/www_authenticate_parser'
require 'mechanize/image'
require 'mechanize/page'
require 'mechanize/pluggable_parsers'
require 'mechanize/redirect_limit_reached_error'
require 'mechanize/redirect_not_get_or_head_error'
require 'mechanize/response_code_error'
require 'mechanize/robots_disallowed_error'
require 'mechanize/unauthorized_error'
require 'mechanize/unsupported_scheme_error'
require 'mechanize/util'

