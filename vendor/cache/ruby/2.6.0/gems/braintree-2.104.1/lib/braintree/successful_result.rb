module Braintree
  class SuccessfulResult
    include BaseModule

    attr_reader :address
    attr_reader :apple_pay_options
    attr_reader :credentials
    attr_reader :credit_card
    attr_reader :customer
    attr_reader :disputes
    attr_reader :document_upload
    attr_reader :evidence
    attr_reader :merchant
    attr_reader :merchant_account
    attr_reader :merchant_accounts
    attr_reader :new_transaction
    attr_reader :payment_method
    attr_reader :payment_method_nonce
    attr_reader :paypal_account
    attr_reader :settlement_batch_summary
    attr_reader :subscription
    attr_reader :supported_networks
    attr_reader :transaction
    attr_reader :us_bank_account_verification
    attr_reader :credit_card_verification

    def initialize(attributes = {}) # :nodoc:
      @attrs = attributes.keys
      attributes.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      @credit_card_verification = @verification
    end

    def inspect # :nodoc:
      inspected_attributes = @attrs.map { |attr| "#{attr}:#{send(attr).inspect}" }
      "#<#{self.class} #{inspected_attributes.join(" ")}>"
    end

    def success?
      true
    end
  end
end
