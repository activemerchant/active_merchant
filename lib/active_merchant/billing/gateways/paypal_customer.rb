module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCustomerGateway < PaypalExpressRestGateway

      def create_order(options)
        post('v2/checkout/orders', options)
      end

      def get_token(options)
        post('v1/oauth2/token', options)
      end

      def authorize(order_id, options)
        post("v2/checkout/orders/#{ order_id }/authorize", options)
      end

      def handle_approve(operator_required_id, operator, options)
        operator == "authorize" ? authorize(operator_required_id, options) : do_capture(operator_required_id, options)
      end

      def capture(order_id, options)
        post("v2/checkout/orders/#{ order_id }/capture", options)
      end

      def refund(capture_id, options)
        post("v2/payments/captures/#{ capture_id }/refund", options)
      end

      def void(authorization_id, options)
        post("v2/payments/authorizations/#{ authorization_id }/void", options)
      end

      def update_order(order_id, options)
        patch("v2/checkout/orders/#{ order_id }", options)
      end

      def disburse(options)
        post("v1/payments/referenced-payouts-items", options)
      end

      def do_capture(authorization_id, options)
        post("v2/payments/authorizations/#{ authorization_id }/capture", options)
      end
    end
  end
end
## Calling Mechanism
# paypal_customer = ActiveMerchant::Billing::PaypalCustomer.new(paypal_options)
# paypal_customer.register_partner({})
