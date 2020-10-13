module Braintree
  class UsBankAccountGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def find(token)
      raise ArgumentError if token.nil? || token.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/payment_methods/us_bank_account/#{token}")
      UsBankAccount._new(@gateway, response[:us_bank_account])
    rescue NotFoundError
      raise NotFoundError, "payment method with token #{token.inspect} not found"
    end
  end
end
