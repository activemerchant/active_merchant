require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstPayGateway < Gateway
      self.live_url = 'https://secure.1stpaygateway.net/secure/gateway/xmlgateway.aspx'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://1stpaygateway.net/'
      self.display_name = '1stPayGateway.Net'

      def initialize(options={})
        requires!(options, :transaction_center_id, :gateway_id)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('auth', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_reference(post, 'settle', money, authorization)
        commit('settle', post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_reference(post, 'credit', money, authorization)
        commit('credit', post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, 'void', nil, authorization)
        commit('void', post)
      end

      private

      def add_authentication(post, options)
        post[:transaction_center_id] = options[:transaction_center_id]
        post[:gateway_id] = options[:gateway_id]
      end

      def add_customer_data(post, options)
        post[:owner_email] = options[:email] if options[:email]
        post[:remote_ip_address] = options[:ip] if options[:ip]
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address]
        post[:owner_name] = address[:name]
        post[:owner_street] = address[:address1]
        post[:owner_street2] = address[:address2] if address[:address2]
        post[:owner_city] = address[:city]
        post[:owner_state] = address[:state]
        post[:owner_zip] = address[:zip]
        post[:owner_country] = address[:country]
        post[:owner_phone] = address[:phone] if address[:phone]
      end

      def add_invoice(post, money, options)
        post[:order_id] = options[:order_id]
        post[:total] = amount(money)
      end

      def add_payment(post, payment)
        post[:card_name] = payment.brand # Unclear if need to map to known names or open text field??
        post[:card_number] = payment.number
        post[:card_exp] = expdate(payment)
        post[:cvv2] = payment.verification_value
      end

      def add_reference(post, action, money, authorization)
        post[:"#{action}_amount1"] = amount(money) if money
        post[:total_number_transactions] = 1
        post[:reference_number1] = authorization
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath("//RESPONSE/FIELDS/FIELD").each do |field|
          response[field['KEY']] = field.text
        end unless doc.root.nil?

        response
      end

      def commit(action, parameters)
        response = parse(ssl_post(live_url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        (
          (response['status'] == '1') ||
          (response['status1'] == '1')
        )
      end

      def message_from(response)
        # Silly inconsistent gateway. Always make capitalized (but not all caps)
        msg = (response['auth_response'] || response['response1'])
        msg.downcase.capitalize if msg
      end

      def authorization_from(response)
        response['reference_number'] || response['reference_number1']
      end

      def post_data(action, parameters = {})
        parameters[:transaction_center_id] = @options[:transaction_center_id]
        parameters[:gateway_id] = @options[:gateway_id]

        parameters[:operation_type] = action

        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'TRANSACTION' do
          xml.tag! 'FIELDS' do
            parameters.each do |key, value|
              xml.tag! 'FIELD', value, { 'KEY' => key }
            end
          end
        end
        xml.target!
      end
    end
  end
end
