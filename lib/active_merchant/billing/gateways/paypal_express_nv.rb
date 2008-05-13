require File.dirname(__FILE__) + '/paypal_nv/paypal_nv_common_api'
require File.dirname(__FILE__) + '/paypal_nv/paypal_express_nv_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressNvGateway < Gateway
      include PaypalNvCommonAPI

      self.supported_countries = ['US']

      LIVE_REDIRECT_NV_URL = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token='
      TEST_REDIRECT_NV_URL = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='

      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PayPal Express Checkout'

      def redirect_url
        test? ? TEST_REDIRECT_NV_URL : LIVE_REDIRECT_NV_URL
      end

      def redirect_url_for(token, options = {})
        options = {:review => true}.update(options)
        options[:review] ? "#{redirect_url}#{token}" : "#{redirect_url}#{token}&useraction=commit"
      end

      def setup_authorization(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        commit 'SetExpressCheckout', build_setup_request('Authorization', money, options)
      end

      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        commit 'SetExpressCheckout', build_setup_request('Sale', money, options)
      end

      def details_for(token)
        commit 'GetExpressCheckoutDetails', build_get_details_request(token)
      end

      def authorize(money, options = {})
        requires!(options, :token, :payer_id)
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Authorization', money, options)
      end

      def purchase(money, options = {})
        requires!(options, :token, :payer_id)
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Sale', money, options)
      end

      private
      def build_setup_request(action, money, options)
        post = {}
        add_amount(post, money, options)
        add_pair(post, :returnurl, options[:return_url])
        add_pair(post, :cancelurl, options[:cancel_return_url])
        add_pair(post, :ipaddress, options[:ip])
        add_pair(post, :noshipping, options[:no_shipping] ? '1' : '0')
        add_pair(post, :maxamount, options[:max_amount]) if options[:max_amount]
        add_pair(post, :paymentaction, action)
        add_pair(post, :email, options[:email]) if options[:email]
        add_pair(post, :custom, options[:custom_code]) if options[:custom_code]
        add_pair(post, :reqconfirmshipping, options[:confirm_shipping] ? "1" : "0") if options[:confirm_shipping]
        add_pair(post, :addressoverride, options[:address_override] ? "1" : "0") if options[:address_override]
        add_pair(post, :token, options[:token]) if options[:token]
        add_pair(post, :locale, options[:locale]) if options[:locale]
        add_shipping_address(post, optioins[:shipping_address]) if options[:shipping_address]
        post
      end

      def build_get_details_request(token)
        post = {}
        add_pair(post, :token, token)
        post
      end

      def build_sale_or_authorization_request(action, money, options)
        post = {}
        #required
        add_pair(post, :paymentaction, action)
        add_pair(post, :payerid, options[:payer_id])
        add_pair(post, :token, options[:token])
        add_amount(post, money, options)
        add_pair(post, :buttonsource, application_id)

        # optional
        add_pair(post, :currencycode, options[:currency] || "USD")
        add_pair(post, :token, options[:token]) if options[:token]

        post
      end

      def build_response(success, message, response, options = {})
        PaypalExpressNvResponse.new(success, message, response, options)
      end
    end
  end
end
