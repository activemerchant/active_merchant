require 'active_merchant/billing/gateways/payfort/payfort_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayfortGateway < Gateway #:nodoc:
      self.test_url = 'https://sbcheckout.payfort.com/FortAPI'
      self.live_url = 'https://checkout.payfort.com/FortAPI'
      self.supported_countries = %w(EG AE)
      self.default_currency = 'AED'
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'http://www.payfort.com/'
      self.display_name = 'PayFort'

      include ActiveMerchant::Billing::PayfortHelper

      # Creates a new PayfortGateway
      #
      # ==== Options
      #
      # * <tt>:identifier</tt> -- Merchant Identifier (REQUIRED)
      # * <tt>:access_code</tt> -- Access Code (REQUIRED)
      # * <tt>:signature_phrase</tt> -- Request Signature Phrase (REQUIRED)
      def initialize(options = {})
        requires!(options, :identifier, :access_code, :signature_phrase)
        super
      end

      def authorize(amount, credit_card_token, _options = {})
        request_params = {}
        request_params[:amount] = amount
        request_params[:command] = 'AUTHORIZATION'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        request_params[:currency] = options[:currency] || default_currency
        commit(request_params)
      end

      def capture(amount, credit_card_token, options = {})
        request_params[:amount] = amount
        request_params[:command] = 'CAPTURE'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        false
      end

      # Creates a new PayfortGateway
      #
      # ==== Options
      #
      # * <tt>:id</tt> -- Order reference (REQUIRED)
      # * <tt>:email</tt> -- Customer email address (REQUIRED)
      # * <tt>:name</tt> -- Customer name (OPTIONAL)
      # * <tt>:ip</tt> -- Customer IP address (OPTIONAL)
      # * <tt>:currency</tt> -- Currency, defaults to AED (OPTIONAL)
      # rubocop:disable Metrics/MethodLength
      def purchase(amount, credit_card_token, options = {})
        request_params = {}
        request_params[:amount] = amount
        request_params[:command] = 'PURCHASE'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        request_params[:currency] = options[:currency] || default_currency
        request_params[:customer_email] = options[:email]
        request_params[:customer_name] = options[:name]
        request_params[:customer_ip] = options[:ip]
        request_params[:order_description] = options[:description]
        request_params[:return_url] = options[:return_url]
        commit(request_params.compact)
      end
      # rubocop:enable Metrics/MethodLength

      def credit(amount, _funding_source, _options = {})
        request_params[:amount] = amount
        request_params[:command] = 'CREDIT'
        false
      end

      def refund(amount, _reference, _options = {})
        request_params[:amount] = amount
        false
      end

      def verify(payment, options = {}); end

      def payment_page_params_for(order_id, return_url = nil)
        request_params = {}
        request_params[:service_command] = 'TOKENIZATION'
        request_params[:merchant_reference] = order_id.to_s
        request_params[:return_url] = return_url unless return_url.nil?
        build_request_params(request_params)
      end

      def payment_page_url
        url(:page)
      end
    end
  end
end
