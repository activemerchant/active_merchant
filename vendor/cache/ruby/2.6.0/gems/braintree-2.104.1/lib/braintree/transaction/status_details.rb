module Braintree
  class Transaction
    class StatusDetails # :nodoc:
      include BaseModule

      attr_reader :amount
      attr_reader :status
      attr_reader :timestamp
      attr_reader :transaction_source
      attr_reader :user

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
