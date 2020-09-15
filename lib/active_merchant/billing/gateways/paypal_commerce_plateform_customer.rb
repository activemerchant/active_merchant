## Calling Mechanism
# paypal_customer = ActiveMerchant::Billing::PaypalCustomer.new(paypal_options)
# paypal_customer.register_partner({})
#
module ActiveMerchant
  module Billing
    class PaypalCommercePlateformCustomerGateway < PaypalCommercePlatformGateway

      def create_order(intent, options)
        requires!(options.merge!(intent == nil ? { } : { intent: intent }), :intent, :purchase_units)

        post = { }
        add_intent(intent, post)

        add_purchase_units(options[:purchase_units], post) if options[:purchase_units]

        add_payment_instruction(intent, post, options[:payment_instruction]) if options[:payment_instruction]

        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def get_token(options)
        requires!(options[:authorization], :username, :password)

        prepare_request_to_get_access_token(options)
      end

      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post("v2/checkout/orders/#{ order_id }/authorize", options)
      end

      def handle_approve(operator_required_id, options)
        requires!(options.merge({ operator_required_id: operator_required_id }), :operator_required_id, :operator)

        options[:operator] == "authorize" ? authorize(operator_required_id, options) : capture(operator_required_id, options)
      end

      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post("v2/checkout/orders/#{ order_id }/capture", options)
      end

      def refund(capture_id, options={ })
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
        requires!(options[:body], :reference_type, :reference_id)

        post("v1/payments/referenced-payouts-items", options)
      end

      def do_capture(authorization_id, options)
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post("v2/payments/authorizations/#{ authorization_id }/capture", options)
      end

      # <-********************Private Methods**********************->
      private
      def add_purchase_units(options, post)
        post[:purchase_units] = []

        options.map do |purchase_unit|
          purchase_unit_hsh = {  }
          purchase_unit_hsh[:reference_id]              = purchase_unit[:reference_id]
          ## Amount
          purchase_unit_hsh[:amount]                    = { }
          purchase_unit_hsh[:amount][:currency_code]    = purchase_unit[:amount][:currency_code]
          purchase_unit_hsh[:amount][:value]            = purchase_unit[:amount][:value]
          ### Payee
          purchase_unit_hsh[:payee]                     = { }
          purchase_unit_hsh[:payee][:email_address]     = purchase_unit[:payee][:email_address]
          post[:purchase_units] << purchase_unit_hsh
        end
        post
      end

      def add_payment_instruction(intent, options, post)

        post[:payment_instruction] = { }
        post[:payment_instruction][:disbursement_mode]    = intent

        options[:plateform_fees].map do |platform_fee|
          post[:purchase_units][:platform_fees][:amount]                      = { }
          post[:payment_instruction][:platform_fees][:amount][:currency_code] = platform_fee[:amount][:currency_code]
          post[:payment_instruction][:plateform_fees][:amount][:value]        = platform_fee[:amount][:value]

          post[:payment_instruction][:platform_fees][:payee]                  = { }
          post[:payment_instruction][:plateform_fees][:payee][:email_address] = platform_fee[:payee][:email_address]
        end
        post
      end

      def add_intent(intent, post)
        post[:intent]  = intent
        post
      end
    end
  end
end
