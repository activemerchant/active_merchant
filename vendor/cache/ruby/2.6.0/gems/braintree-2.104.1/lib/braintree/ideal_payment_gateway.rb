module Braintree
  # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
  # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
  class IdealPaymentGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def find(ideal_payment_id)
      raise ArgumentError if ideal_payment_id.nil? || ideal_payment_id.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/ideal_payments/#{ideal_payment_id}")
      IdealPayment._new(@gateway, response[:ideal_payment])
    rescue NotFoundError
      raise NotFoundError, "ideal payment with ideal_payment_id #{ideal_payment_id.inspect} not found"
    end
  end
end
