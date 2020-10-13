module Braintree
  class Transaction
    class AmexExpressCheckoutDetails
      include BaseModule

      attr_reader :bin
      attr_reader :card_member_expiry_date
      attr_reader :card_member_number
      attr_reader :card_type
      attr_reader :expiration_month
      attr_reader :expiration_year
      attr_reader :image_url
      attr_reader :source_description
      attr_reader :token

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
