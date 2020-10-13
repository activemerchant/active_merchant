module Braintree
  class ErrorResult

    attr_reader :credit_card_verification
    attr_reader :errors
    attr_reader :merchant_account
    attr_reader :message
    attr_reader :params
    attr_reader :subscription
    attr_reader :transaction
    attr_reader :verification

    def initialize(gateway, data) # :nodoc:
      @gateway = gateway
      @params = data[:params]
      @credit_card_verification = CreditCardVerification._new(data[:verification]) if data[:verification]
      @merchant_account = MerchantAccount._new(gateway, data[:merchant_account]) if data[:merchant_account]
      @message = data[:message]
      @transaction = Transaction._new(gateway, data[:transaction]) if data[:transaction]
      @verification = CreditCardVerification._new(data[:verification]) if data[:verification]
      @subscription = Subscription._new(gateway, data[:subscription]) if data[:subscription]
      @errors = Errors.new(data[:errors])
    end

    def inspect # :nodoc:
      if @credit_card_verification
        verification_inspect = " credit_card_verification: #{@credit_card_verification.inspect}"
      end
      if @transaction
        transaction_inspect = " transaction: #{@transaction.inspect}"
      end
      "#<#{self.class} params:{...} errors:<#{@errors._inner_inspect}>#{verification_inspect}#{transaction_inspect}>"
    end

    # Always returns false.
    def success?
      false
    end
  end
end
