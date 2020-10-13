module Braintree
  class Transaction
    class CoinbaseDetails
      include BaseModule

      attr_reader :user_id
      attr_reader :user_email
      attr_reader :user_name
      attr_reader :token

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
