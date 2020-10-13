class Mechanize::Headers < Hash
  def [](key)
    super(key.downcase)
  end

  def []=(key, value)
    super(key.downcase, value)
  end

  def key?(key)
    super(key.downcase)
  end

  def canonical_each
    block_given? or return enum_for(__method__)
    each { |key, value|
      key = key.capitalize
      key.gsub!(/-([a-z])/) { "-#{$1.upcase}" }
      yield [key, value]
    }
  end
end

