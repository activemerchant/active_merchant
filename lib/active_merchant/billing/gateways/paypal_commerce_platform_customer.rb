## Calling Mechanism
# paypal_customer = ActiveMerchant::Billing::PaypalCustomer.new(paypal_options)
# paypal_customer.register_partner({})
#
module ActiveMerchant
  module Billing
    class PaypalCommercePlatformCustomerGateway < PaypalCommercePlatformGateway

      def create_order(intent, options)
        requires!(options.merge!(intent == nil ? { } : { intent: intent }), :intent, :purchase_units)

        post = { }
        add_intent(intent, post)

        add_purchase_units(options[:purchase_units], post) unless options[:purchase_units].nil?

        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].nil?

        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def get_token(options)
        requires!(options[:authorization], :username, :password)

        prepare_request_to_get_access_token(options)
      end

      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }

        commit(:post, "v2/checkout/orders/#{ order_id }/authorize", post, options[:headers])
      end

      def handle_approve(operator_required_id, options)
        requires!(options.merge({ operator_required_id: operator_required_id }), :operator_required_id, :operator)

        options[:operator] == "authorize" ? authorize(operator_required_id, options) : capture(operator_required_id, options)
      end

      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }

        commit(:post, "v2/checkout/orders/#{ order_id }/capture", post, options[:headers])
      end

      def refund(capture_id, options={ })
        requires!({ capture_id: capture_id }, :capture_id)

        post = { }

        commit(:post, "v2/payments/captures/#{ capture_id }/refund", post, options[:headers])
      end

      def void(authorization_id, options)
        requires!({ authorization_id: authorization_id }, :authorization_id)

        post = { }

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/void", post, options[:headers])
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

        post = {}

        add_amount(options[:body][:amount], post) unless options[:body][:amount].nil?

        add_invoice(options[:body][:invoice_id], post) unless options[:body][:invoice_id].nil?

        add_final_capture(options[:body][:final_capture], post) unless options[:body][:final_capture].nil?

        add_payment_instruction(options[:body][:payment_instruction], post) unless options[:body][:payment_instruction].nil?

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/capture", post, options[:headers])
      end

      # <-********************Private Methods**********************->
      private
      def add_purchase_units(options, post)
        post[:purchase_units] = []

        options.map do |purchase_unit|
          purchase_unit_hsh = {  }
          purchase_unit_hsh[:reference_id]              = purchase_unit[:reference_id]
          ## Amount
          add_amount(purchase_unit[:amount], purchase_unit_hsh)
          ## Payee
          purchase_unit_hsh[:payee]                     = { }
          purchase_unit_hsh[:payee][:email_address]     = purchase_unit[:payee][:email_address]
          post[:purchase_units] << purchase_unit_hsh
        end
        post
      end

      def add_payment_instruction(options, post)
        post[:payment_instruction] = { }

        post[:payment_instruction][:platform_fees] = []
        options[:platform_fees].map do |platform_fee|
          platform_fee_hsh                          = { }

          add_amount(platform_fee[:amount], platform_fee_hsh)

          platform_fee_hsh[:payee]                  = { }
          platform_fee_hsh[:payee][:email_address] = platform_fee[:payee][:email_address]

          post[:payment_instruction][:platform_fees] << platform_fee_hsh
        end
        post
      end

      def add_intent(intent, post)
        post[:intent]  = intent
        post
      end

      def add_amount(amount, parameter)
        parameter[:amount] = {}
        parameter[:amount][:currency_code]   = amount[:currency_code]
        parameter[:amount][:value]           = amount[:value]
        parameter
      end

      def add_invoice(invoice_id, post)
        post[:invoice_id]  = invoice_id
        post
      end

      def add_final_capture(final_capture, post)
        post[:final_capture] = final_capture
        post
      end

    end
  end
end
