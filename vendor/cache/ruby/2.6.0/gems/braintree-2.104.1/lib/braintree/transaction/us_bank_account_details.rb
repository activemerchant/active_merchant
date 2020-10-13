module Braintree
  class Transaction
    class UsBankAccountDetails # :nodoc:
      include BaseModule

      attr_reader :account_holder_name
      attr_reader :account_type
      attr_reader :ach_mandate
      attr_reader :bank_name
      attr_reader :image_url
      attr_reader :last_4
      attr_reader :routing_number
      attr_reader :token

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
        @ach_mandate = attributes[:ach_mandate] ? AchMandate.new(attributes[:ach_mandate]) : nil
      end
    end
  end
end
