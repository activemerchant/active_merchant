require 'mechanize/test_case'

class TestMechanizeFormKeygen < Mechanize::TestCase

  def setup
    super

    keygen = node('keygen',
                  'name' => 'userkey',
                  'challenge' => 'f4832e1d200df3df8c5c859edcabe52f')

    @keygen = Mechanize::Form::Keygen.new keygen
  end

  def test_challenge
    assert_equal "f4832e1d200df3df8c5c859edcabe52f", @keygen.challenge
  end

  def test_key
    assert @keygen.key.kind_of?(OpenSSL::PKey::PKey), "Not an OpenSSL key"
    assert @keygen.key.private?, "Not a private key"
  end

  def test_spki_signature
    spki = OpenSSL::Netscape::SPKI.new @keygen.value
    assert_equal @keygen.challenge, spki.challenge
    assert_equal @keygen.key.public_key.to_pem, spki.public_key.to_pem
    assert spki.verify(@keygen.key.public_key)
  end

end

