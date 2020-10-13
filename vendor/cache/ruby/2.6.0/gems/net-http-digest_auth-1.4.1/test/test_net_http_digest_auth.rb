require 'minitest/autorun'
require 'net/http/digest_auth'

class TestNetHttpDigestAuth < Minitest::Test

  def setup
    @uri = URI.parse "http://www.example.com/"
    @uri.user = 'user'
    @uri.password = 'password'

    @cnonce = '9ea5ff3bd34554a4165bbdc1df91dcff'

    @header = [
      'Digest qop="auth"',
      'realm="www.example.com"',
      'nonce="4107baa081a592a6021660200000cd6c5686ff5f579324402b374d83e2c9"'
    ].join ', '

    @expected = [
      'Digest username="user"',
      'realm="www.example.com"',
      'algorithm=MD5',
      'qop=auth',
      'uri="/"',
      'nonce="4107baa081a592a6021660200000cd6c5686ff5f579324402b374d83e2c9"',
      'nc=00000000',
      'cnonce="9ea5ff3bd34554a4165bbdc1df91dcff"',
      'response="67be92a5e7b38d08679957db04f5da04"'
    ]

    @da = Net::HTTP::DigestAuth.new

    def @da.make_cnonce
      '9ea5ff3bd34554a4165bbdc1df91dcff'
    end
  end

  def expected
    @expected.join ', '
  end

  def test_auth_header
    assert_equal expected, @da.auth_header(@uri, @header, 'GET')

    @expected[6] = 'nc=00000001'
    @expected[8] = 'response="1f5f0cd1588690c1303737f081c0b9bb"'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_auth_header_iis
    @expected[3] = 'qop="auth"'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET', true)
  end

  def test_auth_header_no_qop
    @header.sub! ' qop="auth",', ''

    @expected[8] = 'response="32f6ca1631ccf7c42a8075deff44e470"'
    @expected.delete 'qop=auth'
    @expected.delete 'cnonce="9ea5ff3bd34554a4165bbdc1df91dcff"'
    @expected.delete 'nc=00000000'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_auth_header_opaque
    @expected << 'opaque="5ccc069c403ebaf9f0171e9517f40e41"'
    @header   << 'opaque="5ccc069c403ebaf9f0171e9517f40e41"'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_auth_header_post
    @expected[8] = 'response="d82219e1e5430b136bbae1670fa51d48"'

    assert_equal expected, @da.auth_header(@uri, @header, 'POST')
  end

  def test_auth_header_sess
    @header << ', algorithm=MD5-sess'

    @expected[2] = 'algorithm=MD5-sess'
    @expected[8] = 'response="c22c5bd9112a86ca78ddc1ae772daeeb"'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_auth_header_sha1
    @expected[2] = 'algorithm=SHA1'
    @expected[8] = 'response="2cb62fc18f7b0ebdc34543f896bb77686b4115e4"'

    @header << 'algorithm=SHA1'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_auth_header_unknown_algorithm
    @header << 'algorithm=bogus'

    e = assert_raises Net::HTTP::DigestAuth::Error do
      @da.auth_header @uri, @header, 'GET'
    end
    
    assert_equal 'unknown algorithm "bogus"', e.message
  end

  def test_auth_header_quoted_algorithm
    @header << 'algorithm="MD5"'

    assert_equal expected, @da.auth_header(@uri, @header, 'GET')
  end

  def test_make_cnonce
    da = Net::HTTP::DigestAuth.new

    cnonce = da.make_cnonce
    assert_match %r%\A[a-f\d]{32}\z%, cnonce
    refute_equal cnonce, da.make_cnonce
  end

  def test_next_nonce
    first = @da.next_nonce

    assert_equal first + 1, @da.next_nonce
  end

end

