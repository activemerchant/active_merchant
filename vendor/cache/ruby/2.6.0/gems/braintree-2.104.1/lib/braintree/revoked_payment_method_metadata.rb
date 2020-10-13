module Braintree
  class RevokedPaymentMethodMetadata
    include BaseModule

    attr_reader :customer_id
    attr_reader :token
    attr_reader :revoked_payment_method

    def initialize(gateway, attributes)
      @revoked_payment_method = PaymentMethodParser.parse_payment_method(gateway, attributes)
      @customer_id = @revoked_payment_method.customer_id
      @token = @revoked_payment_method.token
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end
  end
end
