##
# Raised when a POST, PUT, or DELETE request results in a redirect
# see RFC 2616 10.3.2, 10.3.3 http://www.ietf.org/rfc/rfc2616.txt

class Mechanize::RedirectNotGetOrHeadError < Mechanize::Error
  attr_reader :page, :response_code, :verb, :uri
  def initialize(page, verb)
    @page           = page
    @verb           = verb
    @uri            = page.uri
    @response_code  = page.code
  end

  def to_s
    method = @verb.to_s.upcase
    "#{@response_code} redirect received after a #{method} request"
  end

  alias :inspect :to_s
end

