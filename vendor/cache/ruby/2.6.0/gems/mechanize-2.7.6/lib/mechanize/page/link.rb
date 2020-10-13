##
# This class encapsulates links.  It contains the text and the URI for
# 'a' tags parsed out of an HTML page.  If the link contains an image,
# the alt text will be used for that image.
#
# For example, the text for the following links with both be 'Hello World':
#
#   <a href="http://example">Hello World</a>
#   <a href="http://example"><img src="test.jpg" alt="Hello World"></a>

class Mechanize::Page::Link
  attr_reader :node
  attr_reader :href
  attr_reader :attributes
  attr_reader :page
  alias :referer :page

  def initialize(node, mech, page)
    @node       = node
    @attributes = node
    @href       = node['href']
    @mech       = mech
    @page       = page
    @text       = nil
    @uri        = nil
  end

  # Click on this link
  def click
    @mech.click self
  end

  # This method is a shorthand to get link's DOM id.
  # Common usage:
  #   page.link_with(:dom_id => "links_exact_id")
  def dom_id
    node['id']
  end

  # This method is a shorthand to get a link's DOM class
  # Common usage:
  #   page.link_with(:dom_class => "links_exact_class")
  def dom_class
    node['class']
  end

  def pretty_print(q) # :nodoc:
    q.object_group(self) {
      q.breakable; q.pp text
      q.breakable; q.pp href
    }
  end

  alias inspect pretty_inspect # :nodoc:

  # A list of words in the rel attribute, all lower-cased.
  def rel
    @rel ||= (val = attributes['rel']) ? val.downcase.split(' ') : []
  end

  # Test if the rel attribute includes +kind+.
  def rel? kind
    rel.include? kind
  end

  # Test if this link should not be traced.
  def noreferrer?
    rel?('noreferrer')
  end

  # The text content of this link
  def text
    return @text if @text

    @text = @node.inner_text

    # If there is no text, try to find an image and use it's alt text
    if (@text.nil? or @text.empty?) and imgs = @node.search('img') then
      @text = imgs.map do |e|
        e['alt']
      end.join
    end

    @text
  end

  alias :to_s :text

  # A URI for the #href for this link.  The link is first parsed as a raw
  # link.  If that fails parsing an escaped link is attepmted.

  def uri
    @uri ||= if @href then
               begin
                 URI.parse @href
               rescue URI::InvalidURIError
                 URI.parse WEBrick::HTTPUtils.escape @href
               end
             end
  end

  # A fully resolved URI for the #href for this link.
  def resolved_uri
    @mech.resolve uri
  end

end

