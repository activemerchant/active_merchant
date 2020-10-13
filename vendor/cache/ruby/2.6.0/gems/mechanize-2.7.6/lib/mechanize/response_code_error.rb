# This error is raised when Mechanize encounters a response code it does not
# know how to handle.  Currently, this exception will be thrown if Mechanize
# encounters response codes other than 200, 301, or 302.  Any other response
# code is up to the user to handle.

class Mechanize::ResponseCodeError < Mechanize::Error
  attr_reader :response_code
  attr_reader :page

  def initialize(page, message = nil)
    super message

    @page          = page
    @response_code = page.code.to_s
  end

  def to_s
    response_class = Net::HTTPResponse::CODE_TO_OBJ[@response_code]
    out = "#{@response_code} => #{response_class} "
    out << "for #{@page.uri} " if @page.respond_to? :uri # may be HTTPResponse
    out << "-- #{super}"
  end

  alias inspect to_s
end

