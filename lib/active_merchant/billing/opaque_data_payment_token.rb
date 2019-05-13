module ActiveMerchant
  module Billing
    class OpaqueDataPaymentToken < PaymentToken
      attr_reader :data_descriptor, :first_name, :last_name

      def initialize(payment_data, options = {})
        super
        @data_descriptor = @metadata[:data_descriptor]
        raise ArgumentError, 'data_descriptor is required' unless @data_descriptor
      end

      def type
        'opaque_data'
      end
    end
  end
end
