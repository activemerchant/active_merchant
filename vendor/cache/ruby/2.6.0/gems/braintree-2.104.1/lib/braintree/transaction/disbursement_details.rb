module Braintree
  class Transaction
    class DisbursementDetails # :nodoc:
      include BaseModule

      attr_reader :disbursement_date
      attr_reader :settlement_amount
      attr_reader :settlement_currency_exchange_rate
      attr_reader :settlement_currency_iso_code
      attr_reader :success

      alias_method :success?, :success

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end

      def funds_held?
        @funds_held
      end

      def valid?
        !disbursement_date.nil?
      end
    end
  end
end
