##
# Raised when Mechanize encounters an error while reading the response body
# from the server.  Contains the response headers and the response body up to
# the error along with the initial error.

class Mechanize::ResponseReadError < Mechanize::Error

  attr_reader :body_io
  attr_reader :error
  attr_reader :mechanize
  attr_reader :response
  attr_reader :uri

  ##
  # Creates a new ResponseReadError with the +error+ raised, the +response+
  # and the +body_io+ for content read so far.

  def initialize error, response, body_io, uri, mechanize
    @body_io   = body_io
    @error     = error
    @mechanize = mechanize
    @response  = response
    @uri       = uri
  end

  ##
  # Converts this error into a Page, File, etc. based on the content-type

  def force_parse
    @mechanize.parse @uri, @response, @body_io
  end

  def message # :nodoc:
    "#{@error.message} (#{self.class})"
  end

end

