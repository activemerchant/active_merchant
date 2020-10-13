##
# This class encapsulates an XML file. If Mechanize finds a content-type
# of 'text/xml' or 'application/xml' this class will be instantiated and
# returned. This class also opens up the +search+ and +at+ methods available
# on the underlying Nokogiri::XML::Document object.
#
# Example:
#
#   require 'mechanize'
#
#   agent = Mechanize.new
#   xml = agent.get('http://example.org/some-xml-file.xml')
#   xml.class #=> Mechanize::XmlFile
#   xml.search('//foo[@attr="bar"]/etc')

class Mechanize::XmlFile < Mechanize::File
  extend Forwardable

  # The underlying Nokogiri::XML::Document object

  attr_reader :xml

  def initialize(uri = nil, response = nil, body = nil, code = nil)
    super uri, response, body, code
    @xml = Nokogiri.XML body
  end

  ##
  # :method: search
  #
  # Search for +paths+ in the page using Nokogiri's #search.  The +paths+ can
  # be XPath or CSS and an optional Hash of namespaces may be appended.
  #
  # See Nokogiri::XML::Node#search for further details.

  def_delegator :xml, :search, :search

  ##
  # :method: at
  #
  # Search through the page for +path+ under +namespace+ using Nokogiri's #at.
  # The +path+ may be either a CSS or XPath expression.
  #
  # See also Nokogiri::XML::Node#at

  def_delegator :xml, :at, :at
end