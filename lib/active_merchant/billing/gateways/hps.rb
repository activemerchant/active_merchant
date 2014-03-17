require File.dirname(__FILE__) + '/hps/infrastructure/hps_exception_mapper'
require File.dirname(__FILE__) + '/hps/infrastructure/sdk_codes'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HpsGateway < Gateway

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jbc, :diners_club]

      self.homepage_url = 'http://developer.heartlandpaymentsystems.com/SecureSubmit/'
      self.display_name = 'Heartland Payment Systems'

      self.money_format = :cents

      def initialize(options={})
        requires!(options, :secret_api_key)
        @secret_api_key = options[:secret_api_key]
        @developer_id = options[:developer_id] if options[:developer_id]
        @version_number = options[:version_number] if options[:version_number]
        @site_trace = options[:site_trace] if options[:site_trace]

        @exception_mapper = Hps::ExceptionMapper.new()
        super
      end
      
      def authorize(money, card_or_token, options={})
        request_multi_use_token = add_multi_use(options)

        if valid_amount?(money)
          xml = Builder::XmlMarkup.new
          xml.hps :Transaction do
            xml.hps :CreditAuth do
              xml.hps :Block1 do
                xml.hps :AllowDup, 'Y'
                xml.hps :Amt, amount(money)
                xml << add_customer_data(card_or_token,options)
                xml << add_details(options)
                xml.hps :CardData do
                  xml << add_payment(card_or_token)

                  xml.hps :TokenRequest, request_multi_use_token ? 'Y' : 'N'

                end
              end
            end
          end
          submit_auth_or_purchase 'CreditAuth', xml.target!, money
        else
          @exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_amount)
        end
      end

      def purchase(money, payment, options={})

        card_or_token = add_payment(payment)
        card_holder = add_customer_data(payment,options)
        request_multi_use_token = add_multi_use(options)
        details = add_details(options)

        begin
          commit @service.charge(money, default_currency, card_or_token, card_holder, request_multi_use_token, details)
        rescue Hps::HpsException => e
          build_error_response(e)
        end
      end


        end
      end

      def capture(money, authorization)
        begin
          commit @service.capture(authorization, money)
        rescue Hps::HpsException => e
          build_error_response(e)
        end
      end

      def refund(money, authorization, options={})
        card_holder = add_customer_data(options["Payment"],options)
        details = add_details(options)

        begin
          commit @service.refund_transaction(money, default_currency, authorization, card_holder, details)
        rescue Hps::HpsException => e
          build_error_response(e)
        end
      end

      def void(authorization)
        begin
          commit @service.void(authorization)
        rescue Hps::HpsException => e
          build_error_response(e)
        end
      end

      def verify(payment, options={})
        card = add_payment(payment)
        card_holder = add_customer_data(payment,options)
        request_multi_use_token = add_multi_use(options)

        begin
          commit @service.verify(card,card_holder,request_multi_use_token)
        rescue Hps::HpsException => e
          build_error_response(e)
        end
      end

      private

      def add_customer_data(payment,options)
        card_holder = nil
        if payment.is_a? Billing::CreditCard
          card_holder = Hps::HpsCardHolder.new()
          card_holder.address = add_address(options)
          card_holder.first_name = payment.first_name
          card_holder.last_name = payment.last_name
          card_holder.email_address = options[:email] if options[:email]
          card_holder.phone = options[:phone] if options[:phone]
        end
        card_holder
      end

      def add_address(options)
        address = Hps::HpsAddress.new()
        billing_address = options[:billing_address] || options[:address]

        unless billing_address.nil?
          address.address = billing_address[:address1] if billing_address[:address1]
          address.address = "#{billing_address[:address1]} #{billing_address[:address2]}" if billing_address[:address2]
          address.city = billing_address[:city] if billing_address[:city]
          address.state = billing_address[:state] if billing_address[:state]
          address.country = billing_address[:country] if billing_address[:country]
          address.zip = billing_address[:zip] if billing_address[:zip]
        end

        address
      end

      def add_payment(payment)
        card = nil
        if payment.is_a? Billing::CreditCard
          card = Hps::HpsCreditCard.new()
          card.number = payment.number
          card.exp_month = payment.month
          card.exp_year = payment.year
          card.cvv = payment.verification_value
        end

        if payment.is_a? String
          card = payment
        end
        card
      end

      def add_details(options)
        details = Hps::HpsTransactionDetails.new()
        details.memo = options[:description] if options[:description]
        details.invoice_number = options[:order_id] if options[:order_id]
        details.customer_id = options[:customer_id] if options[:customer_id]
        details
      end

      def add_multi_use(options)
        multi_use = false
        multi_use = options[:request_multi_use_token] if options[:request_multi_use_token]
        multi_use
      end

      def commit(response)
        build_response(successful?(response), message_from(response),
          {
            :card_type => (response.card_type if response.respond_to?(:card_type) ) ,
            :response_code => (response.response_code if response.respond_to?(:response_code) ),
            :response_text => (response.response_text if response.respond_to?(:response_text) ),
            :transaction_header => (response.transaction_header if response.respond_to?(:transaction_header) ),
            :transaction_id => (response.transaction_id if response.respond_to?(:transaction_id) ),
            :token_data => (response.token_data if response.respond_to?(:token_data) ),
            :full_response => response
          },
          {
            :test => test?,
            :authorization => authorization_from(response),
            :avs_result => {
              :code => (response.avs_result_code if response.respond_to?(:avs_result_code) ),
              :message => (response.avs_result_text if response.respond_to?(:avs_result_text) )
                            },
            :cvv_result => (response.cvv_result_code if response.respond_to?(:cvv_result_code) )
          }
        )
      end

      def build_response(success, message, response, options = {})
        Response.new(success, message, response, options)
      end

      def build_error_response(e)
        Response.new(false,e.message)
      end

      def successful?(response)
        if response.response_code == '00'
          true
        elsif response.is_a? Hps::HpsAccountVerify
          if response.response_code == '85'
            true
          end
        else
          false
        end
      end

      def message_from(response)
        response.transaction_header.gateway_response_message
      end

      def authorization_from(response)
        response.transaction_id
      end

    end
  end
end
