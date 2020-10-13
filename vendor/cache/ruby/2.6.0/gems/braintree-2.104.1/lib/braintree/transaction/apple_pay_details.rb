module Braintree
  class Transaction
    class ApplePayDetails
      include BaseModule

      attr_reader :bin
      attr_reader :card_type
      attr_reader :cardholder_name
      attr_reader :expiration_month
      attr_reader :expiration_year
      attr_reader :image_url
      attr_reader :last_4
      attr_reader :payment_instrument_name
      attr_reader :source_description
      attr_reader :token
      attr_reader :prepaid
      attr_reader :healthcare
      attr_reader :debit
      attr_reader :durbin_regulated
      attr_reader :commercial
      attr_reader :payroll
      attr_reader :issuing_bank
      attr_reader :country_of_issuance
      attr_reader :product_id
      attr_reader :global_id

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
