require "cgi"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantOneGateway < Gateway

      class MerchantOneSslConnection < ActiveMerchant::Connection
        def configure_ssl(http)
          super(http)
          http.use_ssl = true
        end
      end

      BASE_URL = 'https://secure.merchantonegateway.com/api/transact.php'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://merchantone.com/'
      self.display_name = 'Merchant One Gateway'
      self.money_format = :dollars

      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_customer_data(post, options)
        add_creditcard(post, creditcard, options)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        commit('auth', post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_customer_data(post, options)
        add_creditcard(post, creditcard, options)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        commit('sale', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post.merge!(:transactionid => authorization)
        add_amount(post, money, options)
        commit('capture', post)
      end

      def void(authorization, option = {})
        post = {}
        add_transaction_data(post, authorization)
        commit('void', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post.merge!(:transactionid => authorization)
        add_amount(post, money, options)
        commit('refund', post)
      end

      def store(creditcard, options = {})
        post = {}
        type = nil
        add_customer_vault_method_call(post, 'add_customer')
        add_customer_data(post, options)
        add_creditcard(post, creditcard, options)
        add_address(post, creditcard, options)
        commit(type, post)
      end

      def unstore(customer_vault_id, options = {})
        post = {}
        type = nil
        add_customer_vault_method_call(post, 'delete_customer')
        add_customer_profile(post, customer_vault_id)
        commit(type, post)
      end

      def new_connection(endpoint)
        MerchantOneSslConnection.new(endpoint)
      end

      private

      def add_customer_data(post, options)
        post[:firstname] = options[:billing_address][:first_name]
        post[:lastname] = options[:billing_address][:last_name]
      end

      def add_customer_profile(post, customer_vault_id)
        post[:customer_vault_id] = customer_vault_id
      end

      def add_customer_vault_method_call(post, method)
        post[:customer_vault] = method
      end

      def add_amount(post, money, options)
        post[:amount] = amount(money)
      end

      def add_address(post, creditcard, options)
        post[:address1] = options[:billing_address][:address1]
        post[:city] = options[:billing_address][:city]
        post[:state] = options[:billing_address][:state]
        post[:zip] = options[:billing_address][:zip]
        post[:country] = options[:billing_address][:country]
      end

      def add_creditcard(post, creditcard, options = {})
        if creditcard.is_a?(String)
          post[:customer_vault_id] = creditcard
          post[:cvv]               = options[:cvv]
        else
          post[:cvv] = creditcard.verification_value
          post[:ccnumber] = creditcard.number
          post[:ccexp] =  "#{sprintf("%02d", creditcard.month)}#{"#{creditcard.year}"[-2, 2]}"
        end
      end

      def add_transaction_data(post, authorization)
        post[:transactionid] = authorization
      end

      def commit(action, parameters={})
        parameters['username'] = @options[:username]
        parameters['password'] = @options[:password]
        parse(ssl_post(BASE_URL,post_data(action, parameters)))
      end

      def post_data(action, parameters = {})
        parameters.merge!({:type => action}) unless action.nil? || action.empty?
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
        responses =  CGI.parse(data).inject({}){|h,(k, v)| h[k] = v.first; h}
        Response.new(
          (responses["response"].to_i == 1),
          responses["responsetext"],
          responses,
          :test => test?,
          :authorization => authorization_for(responses)
        )
      end

      def authorization_for(response)
        if response["transactionid"].to_s.empty?
          response["customer_vault_id"]
        else
          response["transactionid"]
        end
      end
    end
  end
end

