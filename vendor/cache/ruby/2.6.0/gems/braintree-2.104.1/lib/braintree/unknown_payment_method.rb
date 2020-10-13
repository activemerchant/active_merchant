module Braintree
  class UnknownPaymentMethod
    include BaseModule

    attr_reader :customer_id
    attr_reader :token

    def initialize(gateway, attributes)
      @gateway = gateway
      nested_attributes = attributes[attributes.keys.first]
      set_instance_variables_from_hash(nested_attributes)
    end

    def default?
      @default
    end

    def image_url
      "https://assets.braintreegateway.com/payment_method_logo/unknown.png"
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end
  end
end
