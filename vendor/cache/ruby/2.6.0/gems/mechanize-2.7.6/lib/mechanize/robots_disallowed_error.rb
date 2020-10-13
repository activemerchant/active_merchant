# Exception that is raised when an access to a resource is disallowed by
# robots.txt or by HTML document itself.

class Mechanize::RobotsDisallowedError < Mechanize::Error
  def initialize(url)
    if url.is_a?(URI)
      @url = url.to_s
      @uri = url
    else
      @url = url.to_s
    end
  end

  # Returns the URL (string) of the resource that caused this error.
  attr_reader :url

  # Returns the URL (URI object) of the resource that caused this
  # error.  URI::InvalidURIError may be raised if the URL happens to
  # be invalid or not understood by the URI library.
  def uri
    @uri ||= URI.parse(url)
  end

  def to_s
    "Robots access is disallowed for URL: #{url}"
  end
  alias :inspect :to_s
end
