module Braintree
  class Dispute
    class TransactionDetails # :nodoc:
      include BaseModule

      attr_reader :amount
      attr_reader :id

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
        @amount = Util.to_big_decimal(amount)
      end
    end
  end
end
