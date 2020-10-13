module Braintree
  class PayPalAccountGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def find(token)
      raise ArgumentError if token.nil? || token.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/payment_methods/paypal_account/#{token}")
      PayPalAccount._new(@gateway, response[:paypal_account])
    rescue NotFoundError
      raise NotFoundError, "payment method with token #{token.inspect} not found"
    end

    def create(attributes)
      Util.verify_keys(PayPalAccountGateway._create_signature, attributes)
      _do_create("/payment_methods", :paypal_account => attributes)
    end

    def update(token, attributes)
      Util.verify_keys(PayPalAccountGateway._update_signature, attributes)
      _do_update(:put, "/payment_methods/paypal_account/#{token}", :paypal_account => attributes)
    end

    def delete(token)
      @config.http.delete("#{@config.base_merchant_path}/payment_methods/paypal_account/#{token}")
    end

    def _do_create(path, params) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)
      if response[:paypal_account]
        SuccessfulResult.new(:paypal_account => PayPalAccount._new(@gateway, response[:paypal_account]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :paypal_account or :api_error_response"
      end
    end

    def _do_update(http_verb, path, params) # :nodoc:
      response = @config.http.send(http_verb, "#{@config.base_merchant_path}#{path}", params)
      if response[:paypal_account]
        SuccessfulResult.new(:paypal_account => PayPalAccount._new(@gateway, response[:paypal_account]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :paypal_account or :api_error_response"
      end
    end

    def self._create_signature # :nodoc:
      options = [:fail_on_duplicate_payment_method, :make_default]
      [
        :email, :token, :billing_agreement_id, :customer_id,
        {:options => options},
      ]
    end

    def self._create_nested_signature # :nodoc:
      [
        :email, :token, :billing_agreement_id,
        {:options => [:make_default]}
      ]
    end

    def self._update_signature # :nodoc:
      options = [:fail_on_duplicate_payment_method, :make_default]
      [:email, :token, :billing_agreement_id, {:options => options}]
    end
  end
end
