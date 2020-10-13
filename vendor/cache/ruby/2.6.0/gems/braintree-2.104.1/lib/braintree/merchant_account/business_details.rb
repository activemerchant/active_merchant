module Braintree
  class MerchantAccount
    class BusinessDetails
      include BaseModule

      attr_reader :address_details
      attr_reader :dba_name
      attr_reader :legal_name
      attr_reader :tax_id

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
        @address_details = MerchantAccount::AddressDetails.new(@address)
      end
    end
  end
end
