module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AuthorizeNetPaymentNonce < Model
      # This is a representation of the token object specified here:
      # https://developer.authorize.net/api/reference/index.html#accept-suite-create-an-accept-payment-transaction
      # https://developer.authorize.net/api/reference/features/acceptjs.html#Using_the_Payment_Nonce_in_an_API_Request_From_Your_Server

      attr_accessor :first_name, :last_name, :nonce

      def type
        'tokenized'
      end
    end
  end
end
