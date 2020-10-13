module Braintree
  class Dispute
    class Transaction # :nodoc:
      include BaseModule

      attr_reader :amount
      attr_reader :created_at
      attr_reader :id
      attr_reader :installment_count
      attr_reader :order_id
      attr_reader :purchase_order_number
      attr_reader :payment_instrument_subtype

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
        @amount = Util.to_big_decimal(amount)
      end
    end
  end
end
