require 'webrobots/version'
require 'webrobots/robotstxt'
require 'uri'
require 'net/https'
require 'thread'
if defined?(Nokogiri)
  require 'webrobots/nokogiri'
else
  autoload :Nokogiri, 'webrobots/nokogiri'
end

class WebRobots
  # Creates a WebRobots object for a robot named +user_agent+, with
  # optional +options+.
  #
  # * :http_get => a custom method, proc, or anything that responds to
  #   .call(uri), to be used for fetching robots.txt.  It must return
  #   the response body if successful, return an empty string if the
  #   resource is not found, and return nil or raise any error on
  #   failure.  Redirects should be handled within this proc.
  #
  # * :crawl_delay => determines how to react to Crawl-delay
  #   directives.  If +:sleep+ is given, WebRobots sleeps as demanded
  #   when allowed?(url)/disallowed?(url) is called.  This is the
  #   default behavior.  If +:ignore+ is given, WebRobots does
  #   nothing.  If a custom method, proc, or anything that responds to
  #   .call(delay, last_checked_at), it is called.
  def initialize(user_agent, options = nil)
    @user_agent = user_agent

    options ||= {}
    @http_get = options[:http_get] || method(:http_get)
    crawl_delay_handler =
      case value = options[:crawl_delay] || :sleep
      when :ignore
        nil
      when :sleep
        method(:crawl_delay_handler)
      else
        if value.respond_to?(:call)
          value
        else
          raise ArgumentError, "invalid Crawl-delay handler: #{value.inspect}"
        end
      end

    @parser = RobotsTxt::Parser.new(user_agent, crawl_delay_handler)
    @parser_mutex = Mutex.new

    @robotstxt = create_cache()
  end

  # :nodoc:
  def create_cache
    Hash.new	# Must respond to [], []=, delete and clear.
  end

  # Flushes robots.txt cache.
  def flush_cache
    @robotstxt.clear
  end

  # Returns the robot name initially given.
  attr_reader :user_agent

  # Tests if the robot is allowed to access a resource at +url+.  If a
  # malformed URI string is given, URI::InvalidURIError is raised.  If
  # a relative URI or a non-HTTP/HTTPS URI is given, ArgumentError is
  # raised.
  def allowed?(url)
    site, request_uri = split_uri(url)
    return true if request_uri == '/robots.txt'
    robots_txt = get_robots_txt(site)
    robots_txt.allow?(request_uri)
  end

  # Equivalent to !allowed?(url).
  def disallowed?(url)
    !allowed?(url)
  end

  # Returns the number of seconds that the configured agent should wait
  # between successive requests to the site identified by +url+ according
  # to the site's robots.txt +Crawl-delay+ directive.
  def crawl_delay(url)
    robots_txt_for(url).crawl_delay()
  end

  # Returns extended option values for a resource at +url+ in a hash
  # with each field name lower-cased.  See allowed?() for a list of
  # errors that may be raised.
  def options(url)
    robots_txt_for(url).options
  end

  # Equivalent to option(url)[token.downcase].
  def option(url, token)
    options(url)[token.downcase]
  end

  # Returns an array of Sitemap URLs.  See allowed?() for a list of
  # errors that may be raised.
  def sitemaps(url)
    robots_txt_for(url).sitemaps
  end

  # Returns an error object if there is an error in fetching or
  # parsing robots.txt of the site +url+.
  def error(url)
    robots_txt_for(url).error
  end

  # Raises the error if there was an error in fetching or parsing
  # robots.txt of the site +url+.
  def error!(url)
    robots_txt_for(url).error!
  end

  # Removes robots.txt cache for the site +url+.
  def reset(url)
    site, = split_uri(url)
    @robotstxt.delete(site)
  end

  private

  def split_uri(url)
    site =
      if url.is_a?(URI)
        url.dup
      else
        begin
          URI.parse(url)
        rescue => e
          raise ArgumentError, e.message
        end
      end

    site.scheme && site.host or
      raise ArgumentError, "non-absolute URI: #{url}"

    site.is_a?(URI::HTTP) or
      raise ArgumentError, "non-HTTP/HTTPS URI: #{url}"

    request_uri = site.request_uri
    if (host = site.host).match(/[[:upper:]]/)
      site.host = host.downcase
    end
    site.path = '/'
    return site, request_uri
  end

  def robots_txt_for(url)
    site, = split_uri(url)
    get_robots_txt(site)
  end

  def get_robots_txt(site)
    @robotstxt[site] ||= fetch_robots_txt(site)
  end

  def fetch_robots_txt(site)
    begin
      body = @http_get.call(site + 'robots.txt') or raise 'robots.txt unfetchable'
    rescue => e
      return RobotsTxt.unfetchable(site, e, @user_agent)
    end
    @parser_mutex.synchronize {
      @parser.parse!(body, site)
    }
  end

  def http_get(uri)
    response = nil
    referer = nil
    5.times {
      http = Net::HTTP.new(uri.host, uri.port)
      if http.use_ssl = uri.is_a?(URI::HTTPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.cert_store = OpenSSL::X509::Store.new.tap { |store|
          store.set_default_paths
        }
      end
      header = { 'User-Agent' => @user_agent }
      header['Referer'] = referer if referer
      # header is destroyed by this in ruby 1.9.2!
      response = http.get(uri.request_uri, header)
      case response
      when Net::HTTPSuccess
        return response.body
      when Net::HTTPRedirection
        referer = uri.to_s
        uri = URI(response['location'])
      when Net::HTTPClientError
        return ''
      end
    }
    case response
    when Net::HTTPRedirection
      # Treat too many redirections as not found
      ''
    else
      raise "#{response.code} #{response.message}"
    end
  end

  def crawl_delay_handler(delay, last_checked_at)
    if last_checked_at
      delay -= Time.now - last_checked_at
      sleep delay if delay > 0
    end
  end
end
