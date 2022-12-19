require 'rack'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FifthDlGateway < Gateway
      self.test_url = 'https://secure.5thdl.com/payments/services_api.aspx'
      self.live_url = 'https://secure.5thdl.com/payments/services_api.aspx'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.5thdl.com/'
      self.display_name = '5th Dimension Logistics Gateway'

      SUCCESS_CODES = ['1', '520', '00', '100', 'A']
      ERROR_CODES   = ['3', '550', 'X', 'ER']
      DECLINE_CODES = ['2', '530', '540', 'D', '05', '500']

      def initialize(options={})
        requires!(options, :apikey, :mkey, :apiname)
        @apikey, @mkey, @apiname = options[:apikey], options[:mkey], options[:apiname]
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
        post = { 
          transid: authorization,
          amount: amount(money),
        }

        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = { 
          transid: authorization,
          amount: amount(money),
        }

        commit('refund', post)
      end

      def void(authorization, options={})
        post = { transid: authorization }
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
        post[:firstname] =  options[:firstname]
        post[:lastname] = options[:lastname]
      end

      def add_address(post, creditcard, options)
        address = options[:address]
        return {} if address.blank?
        post[:address1] = address[:address1]
        post[:address2] = address[:address2]
        post[:city] = address[:city]
        post[:state] = address[:state]
        post[:zip] = address[:zip]
        post[:country] = address[:country]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post[:cardnum] = payment.number
        post[:cardexp] = expdate(payment)
        post[:cvv] =  payment.verification_value
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def parse(body)
        Rack::Utils.parse_nested_query(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        SUCCESS_CODES.include?(response['response'])
      end

      def message_from(response)
        response['textresponse'] || response['codedescription']
      end

      def authorization_from(response)
        response['transid']
      end

      def post_data(action, parameters = {})
        parameters.merge!({ 
          transtype: action,
          apikey: @apikey,
          mkey: @mkey,
          apiname: @apiname
        }).to_query
      end
    end
  end
end
