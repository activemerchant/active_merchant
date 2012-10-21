module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FederatedCanadaGateway < Gateway
      # Same URL for both test and live, testing is done by using the test username (demo) and password (password).
      self.live_url = self.test_url = 'https://secure.federatedgateway.com/api/transact.php'

      APPROVED, DECLINED, ERROR = 1, 2, 3

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA']

      self.default_currency = 'CAD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.federatedcanada.com/'

      # The name of the gateway
      self.display_name = 'Federated Canada'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        commit('sale', money, post)
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        commit('auth', money, post)
      end

      def capture(money, authorization, options = {})
        options[:transactionid] = authorization
        commit('capture', money, options)
      end

      def void(authorization, options = {})
        options[:transactionid] = authorization
        commit('void', nil, options)
      end

      def refund(money, authorization, options = {})
        commit('refund', money, options.merge(:transactionid => authorization))
      end

      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      private

      def add_customer_data(post, options)
        post[:firstname] = options[:first_name]
        post[:lastname] = options[:last_name]

        post[:email] = options[:email]
      end

      def add_address(post, options)
        if address = (options[:billing_address] || options[:address])
          post[:company] = address[:company]
          post[:address1] = address[:address1]
          post[:address2] = address[:address2]
          post[:city]    = address[:city]
          post[:state]   = address[:state]
          post[:zip]     = address[:zip]
          post[:country] = address[:country]
          post[:phone] = address[:phone]
        end
        if address = options[:shipping_address]
          post[:shipping_firstname] = address[:first_name]
          post[:shipping_lastname] = address[:last_name]
          post[:shipping_company] = address[:company]
          post[:shipping_address1] = address[:address1]
          post[:shipping_address2] = address[:address2]
          post[:shipping_city]    = address[:city]
          post[:shipping_state]   = address[:state]
          post[:shipping_zip]     = address[:zip]
          post[:shipping_country] = address[:country]
          post[:shipping_email]   = address[:email]
        end
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id]
        post[:orderdescription] = options[:description]
      end
      
      def add_creditcard(post, creditcard)
        post[:ccnumber] = creditcard.number
        post[:ccexp] = expdate(creditcard)
        post[:cvv] = creditcard.verification_value
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        "#{month}#{year[-2..-1]}"
      end

      def parse(body)
        body.split('&').inject({}) do |memo, x|
          k, v = x.split('=')
          memo[k] = v
          memo
        end
      end
      
      def commit(action, money, parameters)
        parameters[:amount] = amount(money)
        data = ssl_post(self.live_url, post_data(action, parameters))
        response = parse(data)
        message = message_from(response)
        test_mode = test?

        Response.new(success?(response), message, response, 
          :test => test?,
          :authorization => response['transactionid'],
          :avs_result => {:code =>  response['avsresponse']},
          :cvv_result => response['cvvresponse']
        )
      end

      def success?(response)
        response['response'] == '1'
      end

      def test?
        (@options[:login].eql?('demo')) && (@options[:password].eql?('password'))
      end

      def message_from(response)
        case response['response'].to_i
        when APPROVED
          "Transaction Approved"
        when DECLINED
          "Transaction Declined"
        else
          "Error in transaction data or system error"
        end
      end

      def post_data(action, parameters = {})
        parameters[:type] = action
        parameters[:username] = @options[:login]
        parameters[:password] = @options[:password]
        parameters.map{|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end
    end
  end
end

