class Mechanize::HTTP::AuthRealm

  attr_reader :scheme
  attr_reader :uri
  attr_reader :realm

  def initialize scheme, uri, realm
    @scheme = scheme
    @uri    = uri
    @realm  = realm if realm
  end

  def == other
    self.class === other and
      @scheme == other.scheme and
      @uri    == other.uri    and
      @realm  == other.realm
  end

  alias eql? ==

  def hash # :nodoc:
    [@scheme, @uri, @realm].hash
  end

  def inspect # :nodoc:
    "#<AuthRealm %s %p \"%s\">" % [@scheme, @uri, @realm]
  end

end

