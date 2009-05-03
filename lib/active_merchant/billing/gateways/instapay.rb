module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class InstapayGateway < Gateway
      GATEWAY_URL = 'https://trans.instapaygateway.com/cgi-bin/process.cgi'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      self.money_format = :dollars
      self.default_currency = 'USD'
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.instapayllc.com'

      # The name of the gateway
      self.display_name = 'InstaPay'

      def initialize(options = {})
        requires!(options, :acctid)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        post[:authonly] = 1
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('ns_quicksale_cc', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('ns_quicksale_cc', money, post)
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
        post[:ccnum]   = creditcard.number
        post[:expmon]   = format(creditcard.month, :two_digits)
        post[:cvv2]    = creditcard.verification_value if creditcard.verification_value?
        post[:expyear] = creditcard.year
        post[:ccname] = creditcard.name
      end

      def parse(body)
        results = {}
        fields = body.split("\n")
        response = fields[1].split('=')
        results[:response_code]= response[0]
        responsedata = response[1].split(':')
        results[:transaction_id] = responsedata[4]
        results
      end

      def commit(action, money, parameters)
        parameters[:amount] = amount(money)
        data = ssl_post GATEWAY_URL , post_data(action, parameters)
        response = parse(data)
        message = response[:response_code]
        success = response[:response_code] == 'Accepted'
        Response.new(success , message, response,
          :authorization => response[:transaction_id]
        )
      end

      def post_data(action, parameters = {})
        post = {}
        post[:acctid] = @options[:acctid]
        if(@options[:merchantpin])
          post[:merchantpin] = @options[:merchantpin]
        end
        post[:action] = action
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
    end
  end
end

