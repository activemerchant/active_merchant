module Braintree
  class PaymentMethodNonceGateway # :nodoc:
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def create(payment_method_token, args = { payment_method_nonce: {} })
      Util.verify_keys(PaymentMethodNonceGateway._create_signature, args)

      response = @config.http.post("#{@config.base_merchant_path}/payment_methods/#{payment_method_token}/nonces", args)
      payment_method_nonce = PaymentMethodNonce._new(@gateway, response.fetch(:payment_method_nonce))
      SuccessfulResult.new(:payment_method_nonce => payment_method_nonce)
    end

    def self._create_signature
      [ {
        :payment_method_nonce=> [
          :merchant_account_id, :authentication_insight,
          {:authentication_insight_options => [:amount, :recurring_customer_consent, :recurring_max_amount]}
        ]
      }]
    end

    def create!(*args)
      return_object_or_raise(:payment_method_nonce) { create(*args) }
    end

    def find(payment_method_nonce)
      response = @config.http.get("#{@config.base_merchant_path}/payment_method_nonces/#{payment_method_nonce}")
      payment_method_nonce = PaymentMethodNonce._new(@gateway, response.fetch(:payment_method_nonce))
      SuccessfulResult.new(:payment_method_nonce => payment_method_nonce)
    end
  end
end
