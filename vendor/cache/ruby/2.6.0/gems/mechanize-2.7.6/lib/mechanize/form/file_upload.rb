# This class represents a file upload field found in a form.  To use this
# class, set FileUpload#file_data= to the data of the file you want to upload
# and FileUpload#mime_type= to the appropriate mime type of the file.
#
# See the example in EXAMPLES

class Mechanize::Form::FileUpload < Mechanize::Form::Field
  attr_accessor :file_name # File name
  attr_accessor :mime_type # Mime Type (Optional)

  alias :file_data :value
  alias :file_data= :value=

  def initialize node, file_name
    @file_name = Mechanize::Util.html_unescape(file_name)
    @file_data = nil
    @node      = node
    super(node, @file_data)
  end
end

