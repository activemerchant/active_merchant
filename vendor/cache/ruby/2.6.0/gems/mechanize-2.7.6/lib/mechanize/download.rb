##
# Download is a pluggable parser for downloading files without loading them
# into memory first.  You may subclass this class to handle content types you
# do not wish to load into memory first.
#
# See Mechanize::PluggableParser for instructions on using this class.

class Mechanize::Download

  include Mechanize::Parser

  ##
  # The filename for this file based on the content-disposition of the
  # response or the basename of the URL

  attr_accessor :filename

  ##
  # Accessor for the IO-like that contains the body

  attr_reader :body_io

  alias content body_io

  ##
  # Creates a new download retrieved from the given +uri+ and +response+
  # object.  The +body_io+ is an IO-like containing the HTTP response body and
  # +code+ is the HTTP status.

  def initialize uri = nil, response = nil, body_io = nil, code = nil
    @uri      = uri
    @body_io  = body_io
    @code     = code

    @full_path = false unless defined? @full_path

    fill_header response
    extract_filename

    yield self if block_given?
  end

  ##
  # The body of this response as a String.
  #
  # Take care, this may use lots of memory if the response body is large.

  def body
    @body_io.read.tap { @body_io.rewind }
  end

  ##
  # Saves a copy of the body_io to +filename+
  # returns the filename

  def save filename = nil
    filename = find_free_name filename
    save! filename
  end

  alias save_as save

  ##
  # Use this method to save the content of body_io to +filename+.
  # This method will overwrite any existing filename that exists with the
  # same name.
  # returns the filename

  def save! filename = nil
    filename ||= @filename
    dirname = File.dirname filename
    FileUtils.mkdir_p dirname

    open filename, 'wb' do |io|
      until @body_io.eof? do
        io.write @body_io.read 16384
      end
    end

    filename
  end

end

