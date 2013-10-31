module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayscoutGateway < Gateway
      self.live_url = self.test_url = 'https://secure.payscout.com/api/transact.php'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.default_currency = 'USD'
      self.homepage_url = 'http://www.payscout.com/'
      self.display_name = 'Payscout'

      self.ssl_version = 'SSLv3'

      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_currency(post, money, options)
        add_address(post, options)

        commit('auth', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_currency(post, money, options)
        add_address(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:transactionid] = authorization

        commit('capture', money, post)
      end


      def refund(money, authorization, options = {})
        post = {}
        post[:transactionid] = authorization

        commit('refund', money, post)
      end

      def void(authorization, options = {})
        post = {}
        post[:transactionid] = authorization

        commit('void', nil, post)
      end

      private

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:address1] = address[:address1].to_s
          post[:address2] = address[:address2].to_s
          post[:city]     = address[:city].to_s
          post[:state]    = (address[:state].blank?  ? 'n/a' : address[:state])
          post[:zip]      = address[:zip].to_s
          post[:country]  = address[:country].to_s
          post[:phone]    = address[:phone].to_s
          post[:fax]      = address[:fax].to_s
          post[:email]    = address[:email].to_s
        end

        if address = options[:shipping_address]
          post[:shipping_firstname] = address[:first_name].to_s
          post[:shipping_lastname]  = address[:last_name].to_s
          post[:shipping_company]   = address[:company].to_s
          post[:shipping_address1]  = address[:address1].to_s
          post[:shipping_address2]  = address[:address2].to_s
          post[:shipping_city]      = address[:city].to_s
          post[:shipping_country]   = address[:country].to_s
          post[:shipping_state]     = (address[:state].blank?  ? 'n/a' : address[:state])
          post[:shipping_zip]       = address[:zip].to_s
          post[:shipping_email]     = address[:email].to_s
        end
      end

      def add_currency(post, money, options)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_invoice(post, options)
        post[:orderdescription] = options[:description]
        post[:orderid]          = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:ccnumber]  = creditcard.number
        post[:cvv]       = creditcard.verification_value if creditcard.verification_value?
        post[:ccexp]     = expdate(creditcard)
        post[:firstname] = creditcard.first_name
        post[:lastname]  = creditcard.last_name
      end

      def parse(body)
        Hash[body.split('&').map{|x|x.split('=')}]
      end

      def commit(action, money, parameters)
        parameters[:amount] = amount(money) unless action == 'void'
        url = (test? ? self.test_url : self.live_url)
        data = ssl_post(url, post_data(action, parameters))

        response          = parse(data)
        response[:action] = action

        message = message_from(response)
        test_mode = (test? || message =~ /TESTMODE/)
        Response.new(success?(response), message, response,
          :test => test_mode,
          :authorization => response['transactionid'],
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response['avsresponse'] },
          :cvv_result => response['cvvresponse']
        )
      end

      def message_from(response)
        case response['response']
        when '1'
          'The transaction has been approved'
        when '2'
          'The transaction has been declined'
        when '3'
          response['responsetext']
        else
          'There was an error processing the transaction'
        end
      end

      def fraud_review?(response)
        false
      end

      def success?(response)
        (response['response'] == '1')
      end

      def post_data(action, parameters = {})
        post = {}

        post[:username]       = @options[:username]
        post[:password]       = @options[:password]
        post[:type]           = action

        request = post.merge(parameters).collect { |key, value| "#{key}=#{URI.escape(value.to_s)}" }.join("&")
        request
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
    end
  end
end

