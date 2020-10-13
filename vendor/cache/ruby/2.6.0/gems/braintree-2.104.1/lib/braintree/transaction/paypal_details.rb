module Braintree
  class Transaction
    class PayPalDetails
      include BaseModule

      attr_reader :authorization_id
      attr_reader :capture_id
      attr_reader :custom_field
      attr_reader :debug_id
      attr_reader :description
      attr_reader :image_url
      attr_reader :implicitly_vaulted_payment_method_global_id
      attr_reader :implicitly_vaulted_payment_method_token
      attr_reader :payee_email
      attr_reader :payee_id
      attr_reader :payer_email
      attr_reader :payer_first_name
      attr_reader :payer_id
      attr_reader :payer_last_name
      attr_reader :payer_status
      attr_reader :payment_id
      attr_reader :refund_from_transaction_fee_amount
      attr_reader :refund_from_transaction_fee_currency_iso_code
      attr_reader :refund_id
      attr_reader :seller_protection_status
      attr_reader :token
      attr_reader :transaction_fee_amount
      attr_reader :transaction_fee_currency_iso_code

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
