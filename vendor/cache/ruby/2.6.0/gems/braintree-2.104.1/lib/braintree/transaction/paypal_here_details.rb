module Braintree
  class Transaction
    class PayPalHereDetails
      include BaseModule

      attr_reader :authorization_id
      attr_reader :capture_id
      attr_reader :invoice_id
      attr_reader :last_4
      attr_reader :payment_id
      attr_reader :payment_type
      attr_reader :refund_id
      attr_reader :transaction_fee_amount
      attr_reader :transaction_fee_currency_iso_code
      attr_reader :transaction_initiation_date
      attr_reader :transaction_updated_date

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
