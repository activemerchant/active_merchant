module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuInGateway < Gateway
      self.test_url = 'https://test.payu.in/_payment.php'
      self.live_url = 'https://secure.payu.in/_payment.php'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['IN']

      # The default currency supported by the payment gateway
      self.default_currency = 'INR'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.payu.in/'

      # The name of the gateway
      self.display_name = 'PayU Payments Private Ltd.'

      cattr_accessor :secret_key

      def initialize(options={})
        requires!(options, :merchant_id, :secret_key)
        self.secret_key = options[:secret_key]
        super        
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
      end

      def parse(body)
      end

      def commit(action, money, parameters)
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end

