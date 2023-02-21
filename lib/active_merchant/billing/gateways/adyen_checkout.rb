require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway uses the current Stripe {Payment Intents API}[https://stripe.com/docs/api/payment_intents].
    # For the legacy API, see the Stripe gateway
    class AdyenCheckoutGateway < AdyenGateway
      self.test_url = 'https://checkout-test.adyen.com/'
      self.live_url = 'checkout-live.adyenpayments.com/checkout/'

      CHECKOUT_API_VERSION = 'v70'

      LOCAL_PAYMENT_METHODS = %w[ideal directEbanking sepadirectdebit trustly onlineBanking_PL]

      def initialize(options = {})
        requires!(options, :api_key, :merchant_account)
        @api_key, @prefix, @merchant_account = options.values_at(:api_key, :prefix, :merchant_account)
        @options = options
      end

      def url(action)
        if test?
          "#{test_url}#{endpoint(action)}"
        else
          # Todo enforce requirement of prefix
          "https://#{@prefix}-#{live_url}#{endpoint(action)}"
        end
      end

      def endpoint(action)
        # Todo add correct actions
        "#{CHECKOUT_API_VERSION}/#{action}"
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/json',
          'X-API-KEY' => @api_key.to_s
        }
        headers['Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def show_payment_methods(options)
        post = init_post(options)
        commit('paymentMethods', post, options)
      end

      def authorize(money, payment, options = {})
        post = init_post(options)
        add_payment_method(post, payment, options)
        add_invoice(post, money, options)
        add_return_url(post, options)
        add_line_items(post, options)
        add_extra_data(post, payment, options)
        commit('payments', post, options)
      end

      def handle_redirect(redirect_result)
        post = {
          "details": {
            "redirectResult": redirect_result
          }
        }
        commit('payments/details', post, {})
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(Hash)
          post[:paymentMethod] = payment_method
        else
          card = {
            expiryMonth: credit_card.month,
            expiryYear: credit_card.year,
            holderName: credit_card.name,
            number: credit_card.number,
            cvc: credit_card.verification_value,
            type: 'scheme'
          }

          card.delete_if { |_k, v| v.blank? }
          card[:holderName] ||= 'Not Provided'
          requires!(card, :expiryMonth, :expiryYear, :holderName, :number)
          post[:paymentMethod] = card
        end
      end

      def add_return_url(post, options)
        post[:returnUrl] = options[:return_url]
      end

      def add_line_items(post, options)
        post[:lineItems] = options[:line_items] if options[:line_items]
      end

      def success_from(action, response, options)
        case response.dig('resultCode')
        when 'RedirectShopper'
          return true if LOCAL_PAYMENT_METHODS.include?(response.dig('action', 'paymentMethodType'))

          super
        when 'Received', 'Authorised'
          return true
        else
          false
        end
      end
    end
  end
end
