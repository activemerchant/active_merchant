require 'mechanize/test_case'

class TestMechanizeHttpAuthRealm < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/'
    @AR = Mechanize::HTTP::AuthRealm
    @realm = @AR.new 'Digest', @uri, 'r'
  end

  def test_initialize
    assert_equal 'r', @realm.realm

    realm = @AR.new 'Digest', @uri, 'R'
    refute_equal 'r', realm.realm

    realm = @AR.new 'Digest', @uri, 'R'
    assert_equal 'R', realm.realm

    realm = @AR.new 'Digest', @uri, nil
    assert_nil realm.realm
  end

  def test_equals2
    other = @realm.dup
    assert_equal @realm, other

    other = @AR.new 'Basic', @uri, 'r'
    refute_equal @realm, other

    other = @AR.new 'Digest', URI('http://other.example/'), 'r'
    refute_equal @realm, other

    other = @AR.new 'Digest', @uri, 'R'
    refute_equal @realm, other

    other = @AR.new 'Digest', @uri, 's'
    refute_equal @realm, other
  end

  def test_hash
    h = {}
    h[@realm] = 1

    other = @realm.dup
    assert_equal 1, h[other]

    other = @AR.new 'Basic', @uri, 'r'
    assert_nil h[other]
  end

end

