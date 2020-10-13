##
# This class encapsulates a meta element with a refresh http-equiv.  Mechanize
# treats meta refresh elements just like 'a' tags.  MetaRefresh objects will
# contain links, but most likely will have no text.

class Mechanize::Page::MetaRefresh < Mechanize::Page::Link

  ##
  # Time to wait before next refresh

  attr_reader :delay

  ##
  # This MetaRefresh links did not contain a url= in the content attribute and
  # links to itself.

  attr_reader :link_self

  ##
  # Matches the content attribute of a meta refresh element.  After the match:
  #
  #   $1:: delay
  #   $3:: url

  CONTENT_REGEXP = /^\s*(\d+\.?\d*)\s*(?:;(?:\s*url\s*=\s*(['"]?)(\S*)\2)?\s*)?$/i

  ##
  # Regexp of unsafe URI characters that excludes % for Issue #177

  UNSAFE = /[^\-_.!~*'()a-zA-Z\d;\/?:@&%=+$,\[\]]/

  ##
  # Parses the delay and url from the content attribute of a meta
  # refresh element.
  #
  # Returns an array of [delay, url, link_self], where the first two
  # are strings containing the respective parts of the refresh value,
  # and link_self is a boolean value that indicates whether the url
  # part is missing or empty.  If base_uri, the URI of the current
  # page is given, the value of url becomes an absolute URI.

  def self.parse content, base_uri = nil
    m = CONTENT_REGEXP.match(content) or return

    delay, url = m[1], m[3]
    url &&= url.empty? ? nil : Mechanize::Util.uri_escape(url, UNSAFE)
    link_self = url.nil?
    if base_uri
      url = url ? base_uri + url : base_uri
    end

    return delay, url, link_self
  end

  def self.from_node node, page, uri = nil
    http_equiv = node['http-equiv'] and
      /\ARefresh\z/i =~ http_equiv or return

    delay, uri, link_self = parse node['content'], uri

    return unless delay

    new node, page, delay, uri, link_self
  end

  def initialize node, page, delay, href, link_self = false
    super node, page.mech, page

    @delay     = delay.include?(?.) ? delay.to_f : delay.to_i
    @href      = href
    @link_self = link_self
  end

  def noreferrer?
    true
  end
end

