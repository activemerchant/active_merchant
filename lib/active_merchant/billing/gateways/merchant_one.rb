require 'addressable/uri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantOneGateway < Gateway
      class MerchantOneSslConnection < ActiveMerchant::Connection
        def configure_ssl(http)
          super(http)
          http.use_ssl = true
          http.ssl_version = :SSLv3
        end
      end
      BASE_URL = 'https://secure.merchantonegateway.com/api/transact.php'
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      # The homepage URL of the gateway
      self.homepage_url = 'http://merchantone.com/'
      # The name of the gateway
      self.display_name = 'Merchant One Gateway'
      self.money_format = :dollars

      # Attempt to wrap the extreamly simple MerchantOne Gateway into Active merchant

      # Merchant One uses real user names and password for the account.
      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_customer_data(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        commit('auth', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_customer_data(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post.merge!({transactionid: authorization})
        add_amount(post, money, options)
        commit('capture', money, post)
      end
      # We have to work around some server oddities between Merchant One
      # and ruby. So we build our own connection.
      def new_connection(endpoint)
        MerchantOneSslConnection.new(endpoint)
      end

private
      def add_customer_data(post, options)
        post['firstname'] = options[:billing_address][:first_name]
        post['lastname'] = options[:billing_address][:last_name]
      end
      def add_amount(post, money, options)
        post['amount'] = amount(money)
      end

      def add_address(post, creditcard, options)
        post['address1'] = options[:billing_address][:address1]
        post['city'] = options[:billing_address][:city]
        post['state'] = options[:billing_address][:state]
        post['zip'] = options[:billing_address][:zip]
        post['country'] = options[:billing_address][:country]
      end


      def add_creditcard(post, creditcard)
       post['cvv'] = creditcard.verification_value
       post['ccnumber'] = creditcard.number
       # Format MMYY
       post['ccexp'] =  "#{sprintf("%02d", creditcard.month)}#{"#{creditcard.year}"[-2, 2]}"
      end

      # Add Username and password to all commits
      def commit(action, money, parameters={})
        parameters['username'] = @options[:username]
        parameters['password'] = @options[:password]
        parse(ssl_post(BASE_URL,post_data(action, parameters)))
      end

      # This is a funky way to handel post data but currently,
      # it's the only way that Merchant One accepts the data
      def post_data(action, parameters = {})
        parameters.merge!({type: action})
        ret = ""
        for key in parameters.keys
          ret += "#{key}=#{CGI.escape(parameters[key].to_s)}"
          if key != parameters.keys.last
            ret += "&"
          end
        end
        ret.to_s
      end

      # Same for parsing. Odd, but it's how they work.
      def parse(data)
        # NOTE: The domain name below is simply used to create a full URI to allow URI.parse to parse out the query values
        # for us. It is not used to send any data
        data = '"https://secure.merchantonegateway.com/api/transact.php?' + data
        uri = Addressable::URI.parse(data)
        responses = uri.query_values
        response = Response.new(responses['response'].to_i == 1, responses['responsetext'], responses, test: test?, authorization: responses['transactionid'])
        response
      end
    end
  end
end

