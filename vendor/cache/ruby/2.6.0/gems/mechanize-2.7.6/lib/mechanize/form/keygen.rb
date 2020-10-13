##
# This class represents a keygen (public / private key generator) found in a
# Form. The field will automatically generate a key pair and compute its own
# value to match the challenge. Call key to access the public/private key
# pair.

class Mechanize::Form::Keygen < Mechanize::Form::Field
  # The challenge for this <keygen>.
  attr_reader :challenge

  # The key associated with this <keygen> tag.
  attr_reader :key

  def initialize(node, value = nil)
    super
    @challenge = node['challenge']

    @spki = OpenSSL::Netscape::SPKI.new
    @spki.challenge = @challenge

    @key = nil
    generate_key if value.nil? || value.empty?
  end

  # Generates a key pair and sets the field's value.
  def generate_key(key_size = 2048)
    # Spec at http://dev.w3.org/html5/spec/Overview.html#the-keygen-element
    @key = OpenSSL::PKey::RSA.new key_size
    @spki.public_key = @key.public_key
    @spki.sign @key, OpenSSL::Digest::MD5.new
    self.value = @spki.to_pem
  end
end

