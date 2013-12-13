module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayhubGateway < Gateway
      self.test_url = 'https://checkout.payhub.com/transaction/sale/?mode=staging'
      self.live_url = 'https://checkout.payhub.com/transaction/sale/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://payhub.com/'

      # The name of the gateway
      self.display_name = 'PayHub'

      # Set the currency type
      self.money_format = :dollars

      def initialize(options = {})
        requires!(options, :orgid, :mode)
        super
      end

      def url
        test? ? test_url : live_url
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        
        commit('sale', money, post)
      end


      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end


      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end


      private

      def add_amount(post, money, options)
        post['amount'] = options[:currency] || amount(money) 
      end

      def add_customer_data(post, options)
        puts options[:billing_address].inspect
        post['first_name'] = options[:billing_address][:name]
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address]

        unless address.nil?
          post[:address1]  = address[:address1]
          post[:city]      = address[:city]
          post[:state]     = address[:state]
          post[:zip]       = address[:zip]
        end
      end

      def add_invoice(post, options)
        post[:note] = options[:description]
        post[:invoice] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:cc]     = creditcard.number
        # Ensures that the month is always in a two digit form until we change it on our servers.
        post[:month]  = ("%.2i" % creditcard.month)
        post[:year]   = creditcard.year
        post[:cvv]    = creditcard.verification_value
      end

      def parse(response, post_params)
        response = JSON.parse(response)
        puts JSON.pretty_generate(response)
        response = Hash[response.map{|k,v| [k.downcase, v]}]
        
        success = (response['response_code'] == '00')
        message = "#{response['response_code']}:  #{response['response_text']}"
        options = @options.merge(:test => test?, :authorization => response['approval_code'])

        Response.new(success, message, post_params, options)
      end

      def commit(action, money, parameters)
        parameters['orgid'] = options[:orgid]
        parameters['mode'] = options[:mode]

        post = parameters.to_query
        parse(ssl_post(url, post), parameters)
      end

    end
  end
end

