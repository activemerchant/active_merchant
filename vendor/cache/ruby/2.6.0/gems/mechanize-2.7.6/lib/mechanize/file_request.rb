##
# A wrapper for a file URI that makes a request that works like a
# Net::HTTPRequest

class Mechanize::FileRequest

  attr_accessor :uri

  def initialize uri
    @uri = uri
  end

  def add_field *a
  end

  alias []= add_field

  def path
    @uri.path
  end

  def each_header
  end

  def response_body_permitted?
    true
  end

end

