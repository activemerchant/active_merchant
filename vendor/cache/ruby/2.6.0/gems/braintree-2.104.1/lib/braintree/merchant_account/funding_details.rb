module Braintree
  class MerchantAccount
    class FundingDetails
      include BaseModule

      attr_reader :account_number_last_4
      attr_reader :descriptor
      attr_reader :destination
      attr_reader :email
      attr_reader :mobile_phone
      attr_reader :routing_number

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
