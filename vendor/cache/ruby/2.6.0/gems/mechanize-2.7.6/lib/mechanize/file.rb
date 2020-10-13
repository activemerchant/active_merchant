##
# This is the base class for the Pluggable Parsers.  If Mechanize cannot find
# an appropriate class to use for the content type, this class will be used.
# For example, if you download an image/jpeg, Mechanize will not know how to
# parse it, so this class will be instantiated.
#
# This is a good class to use as the base class for building your own
# pluggable parsers.
#
# == Example
#
#   require 'mechanize'
#
#   agent = Mechanize.new
#   agent.get('http://example.com/foo.jpg').class  #=> Mechanize::File

class Mechanize::File

  include Mechanize::Parser

  ##
  # The HTTP response body, the raw file contents

  attr_accessor :body

  ##
  # The filename for this file based on the content-disposition of the
  # response or the basename of the URL

  attr_accessor :filename

  alias content body

  ##
  # Creates a new file retrieved from the given +uri+ and +response+ object.
  # The +body+ is the HTTP response body and +code+ is the HTTP status.

  def initialize uri = nil, response = nil, body = nil, code = nil
    @uri  = uri
    @body = body
    @code = code

    @full_path = false unless defined? @full_path

    fill_header response
    extract_filename

    yield self if block_given?
  end

  ##
  # Use this method to save the content of this object to +filename+.
  # returns the filename
  #
  #   file.save 'index.html'
  #   file.save 'index.html' # saves to index.html.1
  #
  #   uri = URI 'http://localhost/test.html'
  #   file = Mechanize::File.new uri, nil, ''
  #   filename = file.save  # saves to test.html
  #   puts filename         # test.html

  def save filename = nil
    filename = find_free_name filename
    save! filename
  end

  alias save_as save

  ##
  # Use this method to save the content of this object to +filename+.
  # This method will overwrite any existing filename that exists with the
  # same name.
  # returns the filename
  #
  #   file.save 'index.html'
  #   file.save! 'index.html' # overwrite original file
  #   filename = file.save! 'index.html' # overwrite original file with filename 'index.html'

  def save! filename = nil
    filename ||= @filename
    dirname = File.dirname filename
    FileUtils.mkdir_p dirname

    open filename, 'wb' do |f|
      f.write body
    end

    filename
  end

end

