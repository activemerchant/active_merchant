module Braintree
  class PaymentMethodNonce
    include BaseModule # :nodoc:

    def self.create(*args)
      Configuration.gateway.payment_method_nonce.create(*args)
    end

    def self.create!(*args)
      Configuration.gateway.payment_method_nonce.create!(*args)
    end

    def self.find(*args)
      Configuration.gateway.payment_method_nonce.find(*args)
    end

    attr_reader :bin_data
    attr_reader :details
    attr_reader :nonce
    attr_reader :three_d_secure_info
    attr_reader :type
    attr_reader :authentication_insight

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      @nonce = attributes.fetch(:nonce)
      @type = attributes.fetch(:type)
      @details = attributes.fetch(:details)
      @authentication_insight = attributes.fetch(:authentication_insight, nil)
      @three_d_secure_info = ThreeDSecureInfo.new(attributes[:three_d_secure_info]) if attributes[:three_d_secure_info]
      @bin_data = BinData.new(attributes[:bin_data]) if attributes[:bin_data]
    end

    def to_s # :nodoc:
      nonce
    end

    class << self
      protected :new
    end

    def self._new(gateway, attributes) # :nodoc:
      new(gateway, attributes)
    end
  end
end
