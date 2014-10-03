module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayOnlinePaymentsGateway < Gateway
      self.live_url = self.test_url = 'https://api.worldpay.com'

      self.default_currency = 'GBP'
      self.money_format = :cents

      self.supported_countries = %w(HK US GB AU AD BE CH CY CZ DE DK ES FI FR GI GR HU IE IL IT LI LU MC MT NL NO NZ PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]

      self.homepage_url = 'http://developer.worldpay.com/v1/'
      self.display_name = 'Worldpay Online Payments'

      CARD_CODES = {
          'visa'             => 'VISA-SSL',
          'master'           => 'ECMC-SSL',
          'discover'         => 'DISCOVER-SSL',
          'american_express' => 'AMEX-SSL',
          'jcb'              => 'JCB-SSL',
          'maestro'          => 'MAESTRO-SSL',
          'laser'            => 'LASER-SSL',
          'diners_club'      => 'DINERS-SSL',
          'switch'           => 'MAESTRO-SSL'
      }

      def initialize(options={})
        requires!(options, :client_key)
        requires!(options, :service_key)
        @client_key = options[:client_key]
        @service_key = options[:service_key]
        super
      end

      def purchase(money, credit_card, options={})
        post = {}

        options = {

        }

        tokenize(credit_card)

        add_invoice(post, money, options)
        add_payment(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)


        commit('order', post)
      end

      def authorize(money, payment, options={})
        #we dont use this?
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        #we dont use this?
        commit('capture', post)
      end

      def refund(money, authorization, options={})

        commit('orders/'+options[:orderCode]+'/refund', post)
      end

      def void(authorization, options={})
        #we dont use this?
        commit('void', post)
      end

      def verify(credit_card, options={})
        #we dont use this?
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        {}
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

      def tokenize(options)
        post = {}

        commit(:post, "tokens", post, options)
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end
