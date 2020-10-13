class Mechanize::UnsupportedSchemeError < Mechanize::Error
  attr_accessor :scheme, :uri

  def initialize(scheme, uri)
    @scheme = scheme
    @uri    = uri
  end
end
