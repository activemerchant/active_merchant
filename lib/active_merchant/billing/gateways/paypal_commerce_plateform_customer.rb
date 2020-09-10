module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlateformCustomerGateway < PaypalCommercePlatformGateway

      def create_order(options)
        requires!(options[:body], :intent, :purchase_units)
        post('v2/checkout/orders', options)
      end

      def get_token(options)
        requires!(options[:authorization], :username, :password)

        post('v1/oauth2/token', options)
      end

      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post("v2/checkout/orders/#{ order_id }/authorize", options)
      end

      def handle_approve(operator_required_id, operator, options)
        requires!({ operator_required_id: operator_required_id, operator: operator }, :operator_required_id, :operator)

        operator == "authorize" ? authorize(operator_required_id, options) : capture(operator_required_id, options)
      end

      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post("v2/checkout/orders/#{ order_id }/capture", options)
      end

      def refund(capture_id, options)
        requires!({ capture_id: capture_id }, :capture_id)

        post("v2/payments/captures/#{ capture_id }/refund", options)
      end

      def void(authorization_id, options)
        requires!({ authorization_id: authorization_id }, :authorization_id)

        post("v2/payments/authorizations/#{ authorization_id }/void", options)
      end

      def update_order(order_id, options)
        requires!(options.merge!({ order_id: order_id }), :order_id, :op, :path, :value)

        patch("v2/checkout/orders/#{ order_id }", options)
      end

      def disburse(options)
        requires!(options, :reference_type, :reference_id)

        post("v1/payments/referenced-payouts-items", options)
      end

      def do_capture(authorization_id, options)
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post("v2/payments/authorizations/#{ authorization_id }/capture", options)
      end
    end
  end
end
## Calling Mechanism
# paypal_customer = ActiveMerchant::Billing::PaypalCustomer.new(paypal_options)
# paypal_customer.register_partner({})
