module Braintree
  class MerchantAccount
    class IndividualDetails
      include BaseModule

      attr_reader :address_details
      attr_reader :date_of_birth
      attr_reader :email
      attr_reader :first_name
      attr_reader :last_name
      attr_reader :phone
      attr_reader :ssn_last_4

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
        @address_details = MerchantAccount::AddressDetails.new(@address)
      end
    end
  end
end
