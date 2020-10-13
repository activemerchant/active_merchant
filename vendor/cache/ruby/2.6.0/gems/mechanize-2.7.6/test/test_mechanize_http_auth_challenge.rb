require 'mechanize/test_case'

class TestMechanizeHttpAuthChallenge < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/'
    @AR = Mechanize::HTTP::AuthRealm
    @AC = Mechanize::HTTP::AuthChallenge
    @challenge = @AC.new 'Digest', { 'realm' => 'r' }, 'Digest realm=r'
  end

  def test_realm_basic
    @challenge.scheme = 'Basic'

    expected = @AR.new 'Basic', @uri, 'r'

    assert_equal expected, @challenge.realm(@uri + '/foo')
  end

  def test_realm_digest
    expected = @AR.new 'Digest', @uri, 'r'

    assert_equal expected, @challenge.realm(@uri + '/foo')
  end

  def test_realm_digest_case
    challenge = @AC.new 'Digest', { 'realm' => 'R' }, 'Digest realm=R'

    expected = @AR.new 'Digest', @uri, 'R'

    assert_equal expected, challenge.realm(@uri + '/foo')
  end

  def test_realm_unknown
    @challenge.scheme = 'Unknown'

    e = assert_raises Mechanize::Error do
      @challenge.realm(@uri + '/foo')
    end

    assert_equal 'unknown HTTP authentication scheme Unknown', e.message
  end

  def test_realm_name
    assert_equal 'r', @challenge.realm_name
  end

  def test_realm_name_case
    challenge = @AC.new 'Digest', { 'realm' => 'R' }, 'Digest realm=R'

    assert_equal 'R', challenge.realm_name
  end

  def test_realm_name_ntlm
    challenge = @AC.new 'Negotiate, NTLM'

    assert_nil challenge.realm_name
  end

end

