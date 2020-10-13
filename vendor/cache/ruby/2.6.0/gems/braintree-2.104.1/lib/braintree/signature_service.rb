module Braintree
  class SignatureService
    attr_reader :key

    def initialize(key, digest=Braintree::Digest)
      @key = key
      @digest = digest
    end

    def sign(data)
      query_string = Util.hash_to_query_string(data)
      "#{hash(query_string)}|#{query_string}"
    end

    def hash(data)
      @digest.hexdigest(@key, data)
    end
  end
end
