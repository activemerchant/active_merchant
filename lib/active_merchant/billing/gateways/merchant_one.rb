require 'curb'
require 'addressable/uri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantOneGateway < Gateway
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
        post['username'] = @options[:username]
        post['password'] = @options[:password]
        add_amount(post, money, options)
        commit('capture', money, post)
      end

private

      def add_customer_data(post, options)
        post['firstname'] = options[:billing_address][:first_name]
        post['lastname'] = options[:billing_address][:last_name]
        post['username'] = @options[:username]
        post['password'] = @options[:password]
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
       post['ccexp'] =  "#{sprintf("%02d", creditcard.month)}#{"#{creditcard.year}"[-2, 2]}"
      end

      def commit(action, money, parameters={})
        parse(ssl_post(BASE_URL, post_data(action, parameters)))
      end
      # Have to bypass the normal stucch because of
      # merchant one's server settings.
      def ssl_post(url, data, headers={})
        url = "#{url}?#{data}"
        curlObj = Curl::Easy.new(url)
        curlObj.connect_timeout = 15
        curlObj.timeout = 15
        curlObj.header_in_body = false
        curlObj.ssl_verify_peer = false
        curlObj.post_body = ''
        curlObj.perform()
        data = curlObj.body_str
        data
      end


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

