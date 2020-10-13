module Braintree
  # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
  # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
  class Transaction
    class IdealPaymentDetails # :nodoc:
      include BaseModule

      attr_reader :bic
      attr_reader :ideal_payment_id
      attr_reader :ideal_transaction_id
      attr_reader :image_url
      attr_reader :masked_iban

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
