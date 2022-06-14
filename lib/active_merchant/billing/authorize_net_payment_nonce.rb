module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AuthorizeNetPaymentNonce < Model
      # This is a representation of the token object specified here:
      # https://developer.authorize.net/api/reference/index.html#accept-suite-create-an-accept-payment-transaction
      # https://developer.authorize.net/api/reference/features/acceptjs.html#Using_the_Payment_Nonce_in_an_API_Request_From_Your_Server

      attr_accessor :first_name, :last_name, :nonce

      def name
        @name ||= "#{first_name} #{last_name}".strip
      end

      def name=(value)
        return if empty?(value)

        @name = value
        segments = value.split(' ')
        @last_name = segments.pop
        @first_name = segments.join(' ')
      end

      def type
        'tokenized'
      end
    end
  end
end
