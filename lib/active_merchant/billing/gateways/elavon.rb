require 'active_merchant/billing/gateways/viaklix'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ElavonGateway < Gateway
      include Empty

      class_attribute :test_url, :live_url, :delimiter, :actions

      self.test_url = 'https://api.demo.convergepay.com/VirtualMerchantDemo/process.do'
      self.live_url = 'https://api.convergepay.com/VirtualMerchant/process.do'

      self.display_name = 'Elavon MyVirtualMerchant'
      self.supported_countries = %w(US CA PR DE IE NO PL LU BE NL)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.elavon.com/'

      self.delimiter = "\n"
      self.actions = {
        :purchase => 'CCSALE',
        :credit => 'CCCREDIT',
        :refund => 'CCRETURN',
        :authorize => 'CCAUTHONLY',
        :capture => 'CCFORCE',
        :capture_complete => 'CCCOMPLETE',
        :void => 'CCDELETE',
        :store => 'CCGETTOKEN',
        :update => 'CCUPDATETOKEN',
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        form = {}
        add_salestax(form, options)
        add_invoice(form, options)
        if payment_method.is_a?(String)
          add_token(form, payment_method)
        else
          add_creditcard(form, payment_method)
        end
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        add_ip(form, options)
        commit(:purchase, money, form, options)
      end

      def authorize(money, creditcard, options = {})
        form = {}
        add_salestax(form, options)
        add_invoice(form, options)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        add_ip(form, options)
        commit(:authorize, money, form, options)
      end

      def capture(money, authorization, options = {})
        form = {}
        if options[:credit_card]
          action = :capture
          add_salestax(form, options)
          add_approval_code(form, authorization)
          add_invoice(form, options)
          add_creditcard(form, options[:credit_card])
          add_customer_data(form, options)
          add_test_mode(form, options)
        else
          action = :capture_complete
          add_txn_id(form, authorization)
          add_partial_shipment_flag(form, options)
          add_test_mode(form, options)
        end
        commit(action, money, form, options)
      end

      def refund(money, identification, options = {})
        form = {}
        add_txn_id(form, identification)
        add_test_mode(form, options)
        commit(:refund, money, form, options)
      end

      def void(identification, options = {})
        form = {}
        add_txn_id(form, identification)
        add_test_mode(form, options)
        commit(:void, nil, form, options)
      end

      def credit(money, creditcard, options = {})
        if creditcard.is_a?(String)
          raise ArgumentError, "Reference credits are not supported. Please supply the original credit card or use the #refund method."
        end

        form = {}
        add_invoice(form, options)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:credit, money, form, options)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(creditcard, options = {})
        form = {}
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        add_verification(form, options)
        form[:add_token] = 'Y'
        commit(:store, nil, form, options)
      end

      def update(token, creditcard, options = {})
        form = {}
        add_token(form, token)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:update, nil, form, options)
      end

      private

      def add_invoice(form,options)
        form[:invoice_number] = truncate((options[:order_id] || options[:invoice]), 10)
        form[:description] = truncate(options[:description], 255)
      end

      def add_approval_code(form, authorization)
        form[:approval_code] = authorization.split(';').first
      end

      def add_txn_id(form, authorization)
        form[:txn_id] = authorization.split(';').last
      end

      def authorization_from(response)
        [response['approval_code'], response['txn_id']].join(';')
      end

      def add_creditcard(form, creditcard)
        form[:card_number] = creditcard.number
        form[:exp_date] = expdate(creditcard)

        if creditcard.verification_value?
          add_verification_value(form, creditcard)
        end

        form[:first_name] = truncate(creditcard.first_name, 20)
        form[:last_name] = truncate(creditcard.last_name, 30)
      end

      def add_token(form, token)
        form[:token] = token
      end

      def add_verification_value(form, creditcard)
        form[:cvv2cvc2] = creditcard.verification_value
        form[:cvv2cvc2_indicator] = '1'
      end

      def add_customer_data(form, options)
        form[:email] = truncate(options[:email], 100) unless empty?(options[:email])
        form[:customer_code] = truncate(options[:customer], 10) unless empty?(options[:customer])
        form[:customer_number] = options[:customer_number] unless empty?(options[:customer_number])
        if options[:custom_fields]
          options[:custom_fields].each do |key, value|
            form[key.to_s] = value
          end
        end
      end

      def add_salestax(form, options)
        form[:salestax] = options[:tax] if options[:tax].present?
      end

      def add_address(form, options)
        billing_address = options[:billing_address] || options[:address]

        if billing_address
          form[:avs_address]    = truncate(billing_address[:address1], 30)
          form[:address2]       = truncate(billing_address[:address2], 30)
          form[:avs_zip]        = truncate(billing_address[:zip].to_s.gsub(/[^a-zA-Z0-9]/, ''), 9)
          form[:city]           = truncate(billing_address[:city], 30)
          form[:state]          = truncate(billing_address[:state], 10)
          form[:company]        = truncate(billing_address[:company], 50)
          form[:phone]          = truncate(billing_address[:phone], 20)
          form[:country]        = truncate(billing_address[:country], 50)
        end

        if shipping_address = options[:shipping_address]
          first_name, last_name = split_names(shipping_address[:name])
          form[:ship_to_first_name]     = truncate(first_name, 20)
          form[:ship_to_last_name]      = truncate(last_name, 30)
          form[:ship_to_address1]       = truncate(shipping_address[:address1], 30)
          form[:ship_to_address2]       = truncate(shipping_address[:address2], 30)
          form[:ship_to_city]           = truncate(shipping_address[:city], 30)
          form[:ship_to_state]          = truncate(shipping_address[:state], 10)
          form[:ship_to_company]        = truncate(shipping_address[:company], 50)
          form[:ship_to_country]        = truncate(shipping_address[:country], 50)
          form[:ship_to_zip]            = truncate(shipping_address[:zip], 10)
        end
      end

      def add_verification(form, options)
        form[:verify] = 'Y' if options[:verify]
      end

      def add_test_mode(form, options)
        form[:test_mode] = 'TRUE' if options[:test_mode]
      end

      def add_partial_shipment_flag(form, options)
        form[:partial_shipment_flag] = 'Y' if options[:partial_shipment_flag]
      end

      def add_ip(form, options)
        form[:cardholder_ip] = options[:ip] if options.has_key?(:ip)
      end

      def message_from(response)
        success?(response) ? response['result_message'] : response['errorMessage']
      end

      def success?(response)
        !response.has_key?('errorMessage')
      end

      def commit(action, money, parameters, options)
        parameters[:amount] = amount(money)
        parameters[:transaction_type] = self.actions[action]

        response = parse( ssl_post(test? ? self.test_url : self.live_url, post_data(parameters, options)) )

        Response.new(response['result'] == '0', message_from(response), response,
          :test => @options[:test] || test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => response['avs_response'] },
          :cvv_result => response['cvv2_response']
        )
      end

      def post_data(parameters, options)
        result = preamble
        result.merge!(parameters)
        result.collect { |key, value| post_data_string(key, value, options) }.join("&")
      end

      def post_data_string(key, value, options)
        if custom_field?(key, options)
          "#{key}=#{CGI.escape(value.to_s)}"
        else
          "ssl_#{key}=#{CGI.escape(value.to_s)}"
        end
      end

      def custom_field?(field_name, options)
        return true if options[:custom_fields] && options[:custom_fields].include?(field_name.to_sym)
        field_name == :customer_number
      end

      def preamble
        result = {
          'merchant_id'   => @options[:login],
          'pin'           => @options[:password],
          'show_form'     => 'false',
          'result_format' => 'ASCII'
        }

        result['user_id'] = @options[:user] unless empty?(@options[:user])
        result
      end

      def parse(msg)
        resp = {}
        msg.split(self.delimiter).collect{|li|
            key, value = li.split("=")
            resp[key.to_s.strip.gsub(/^ssl_/, '')] = value.to_s.strip
          }
        resp
      end

    end
  end
end
