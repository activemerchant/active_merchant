require 'active_merchant/billing/gateways/payfort/payfort_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayfortMerchantGateway < Gateway #:nodoc:
      self.test_url = 'https://sbpaymentservices.payfort.com/FortAPI'
      self.live_url = 'https://paymentservices.payfort.com/FortAPI'
      self.supported_countries = %w(EG AE)
      self.default_currency = 'AED'
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.payfort.com/'
      self.display_name = 'PayFort'

      include ActiveMerchant::Billing::PayfortHelper

      # Creates a new PayfortMerchant
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

      # Purchase using PayfortMerchant
      #
      # - amount **Number**
      # - token **String**
      #
      # ==== Options
      #
      # * <tt>:id</tt> -- Order reference (REQUIRED)
      # * <tt>:command</tt> -- (REQUIRED)
      # * <tt>:email</tt> -- Customer email address (REQUIRED)
      # * <tt>:name</tt> -- Customer name (OPTIONAL)
      # * <tt>:ip</tt> -- Customer IP address (OPTIONAL)
      # * <tt>:currency</tt> -- Currency, defaults to AED (OPTIONAL)
      # * <tt>:eci</tt> -- Ecommerce indicator (OPTIONAL)
      # * <tt>:card_security_code</tt> -- security code for the card (OPTIONAL)
      # * <tt>:description</tt> -- description of the order (OPTIONAL)
      # * <tt>:payment_option</tt> -- Payment option
      #     --Possible/ expected values:
      #       - MASTERCARD
      #       - VISA
      #       - AMEX
      #       - MADA (for Purchase operations only)
      # * <tt>:phone_number</tt> -- The customer is phone number (OPTIONAL)
      # * <tt>:remember_me</tt> -- Possible values: - YES, - NO (OPTIONAL)
      # * <tt>:settlement_reference</tt> -- Bank value (OPTIONAL)
      # * <tt>:return_url</tt> -- URL of the Merchant is page (OPTIONAL)
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def purchase(amount, payfort_token, options = {})
        request_params = {}
        request_params[:amount] = amount
        request_params[:eci] = options[:eci]
        request_params[:card_security_code] = options[:card_security_code]
        request_params[:command] = 'PURCHASE'
        request_params[:currency] = options[:currency] || default_currency
        request_params[:customer_email] = options[:email]
        request_params[:customer_name] = options[:name]
        request_params[:customer_ip] = options[:ip]
        request_params[:language] = 'en'
        request_params[:merchant_reference] = options[:id]
        request_params[:order_description] = options[:description]
        request_params[:payment_option] = options[:payment_option]
        request_params[:phone_number] = options[:phone_number]
        request_params[:remember_me] = options[:remember_me]
        request_params[:settlement_reference] = options[:settlement_reference]
        request_params[:signature] = ''
        request_params[:token_name] = payfort_token
        request_params[:return_url] = options[:return_url]
        request_params[:check_3ds] = 'NO'
        commit(request_params.compact)
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end
  end
end
