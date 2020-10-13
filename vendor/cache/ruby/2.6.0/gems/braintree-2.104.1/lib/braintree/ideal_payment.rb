module Braintree
  # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
  # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
  class IdealPayment
    include BaseModule

    attr_reader :amount
    attr_reader :approval_url
    attr_reader :currency
    attr_reader :iban_bank_account
    attr_reader :id
    attr_reader :ideal_transaction_id
    attr_reader :issuer
    attr_reader :order_id
    attr_reader :status

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @iban_bank_account = IbanBankAccount.new(attributes[:iban_bank_account]) if attributes[:iban_bank_account]
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end

    def self.sale(ideal_payment_id, transaction_attributes)
      Configuration.gateway.transaction.sale(transaction_attributes.merge(
          :payment_method_nonce => ideal_payment_id,
          :options => { :submit_for_settlement => true }
        )
      )
    end

    def self.sale!(ideal_payment_id, transaction_attributes)
      return_object_or_raise(:transaction) { sale(ideal_payment_id, transaction_attributes) }
    end

    def self.find(ideal_payment_id)
      Configuration.gateway.ideal_payment.find(ideal_payment_id)
    end

    class IbanBankAccount
      include BaseModule
      attr_reader :account_holder_name
      attr_reader :bic
      attr_reader :description
      attr_reader :iban_account_number_last_4
      attr_reader :iban_country
      attr_reader :masked_iban

      def initialize(attributes) # :nodoc:
        set_instance_variables_from_hash(attributes)
      end
    end
  end
end
