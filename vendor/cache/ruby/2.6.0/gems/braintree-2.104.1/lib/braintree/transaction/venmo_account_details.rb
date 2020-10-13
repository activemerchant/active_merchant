module Braintree
  class Transaction
    class VenmoAccountDetails
      include BaseModule

      attr_reader :image_url
      attr_reader :source_description
      attr_reader :token
      attr_reader :username
      attr_reader :venmo_user_id

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
