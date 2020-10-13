module Braintree
  class Transaction
    class LocalPaymentDetails
      include BaseModule

      attr_reader :capture_id
      attr_reader :custom_field
      attr_reader :debug_id
      attr_reader :description
      attr_reader :funding_source
      attr_reader :payer_id
      attr_reader :payment_id
      attr_reader :refund_from_transaction_fee_amount
      attr_reader :refund_from_transaction_fee_currency_iso_code
      attr_reader :refund_id
      attr_reader :transaction_fee_amount
      attr_reader :transaction_fee_currency_iso_code

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
