module Braintree
  class Subscription
    class StatusDetails # :nodoc:
      include BaseModule

      attr_reader :balance
      attr_reader :price
      attr_reader :status
      attr_reader :subscription_source
      attr_reader :timestamp
      attr_reader :user
      attr_reader :currency_iso_code
      attr_reader :plan_id

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
