module Braintree
  class WebhookNotificationGateway # :nodoc:
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def parse(signature_string, payload)
      raise InvalidSignature, 'signature cannot be nil' if signature_string.nil?
      raise InvalidSignature, 'payload cannot be nil' if payload.nil?
      if payload =~ /[^A-Za-z0-9+=\/\n]/
        raise InvalidSignature, "payload contains illegal characters"
      end
      _verify_signature(signature_string, payload)
      attributes = Xml.hash_from_xml(Base64.decode64(payload))
      WebhookNotification._new(@gateway, attributes[:notification])
    end

    def verify(challenge)
      raise InvalidChallenge, 'challenge contains non-hex characters' unless challenge =~ /\A[a-f0-9]{20,32}\z/
      digest = Braintree::Digest.hexdigest(@config.private_key, challenge)
      "#{@config.public_key}|#{digest}"
    end

    def _matching_signature_pair(signature_string)
      signature_pairs = signature_string.split("&")
      valid_pairs = signature_pairs.select { |pair| pair.include?("|") }.map { |pair| pair.split("|") }

      valid_pairs.detect do |public_key, signature|
        public_key == @config.public_key
      end
    end

    def _verify_signature(signature_string, payload)
      public_key, signature = _matching_signature_pair(signature_string)
      raise InvalidSignature, 'no matching public key' if public_key.nil?

      signature_matches = [payload, payload + "\n"].any? do |payload|
        payload_signature = Braintree::Digest.hexdigest(@config.private_key, payload)
        Braintree::Digest.secure_compare(signature, payload_signature)
      end
      raise InvalidSignature, 'signature does not match payload - one has been modified' unless signature_matches
    end
  end
end
