module Braintree
  module SHA256Digest # :nodoc:
    def self.hexdigest(private_key, string)
      _hmac(private_key, string)
    end

    def self._hmac(key, message)
      key_digest = ::Digest::SHA256.digest(key)
      sha256 = OpenSSL::Digest.new("sha256")
      OpenSSL::HMAC.hexdigest(sha256, key_digest, message.to_s)
    end
  end
end
