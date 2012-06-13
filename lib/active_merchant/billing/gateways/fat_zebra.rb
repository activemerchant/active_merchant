require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FatZebraGateway < Gateway
      LIVE_URL    = "https://gateway.fatzebra.com.au/v1.0"
      SANDBOX_URL = "https://gateway.sandbox.fatzebra.com.au/v1.0"
      LOCAL_URL   = "http://fatapi.dev/v1.0"

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      self.homepage_url = 'https://www.fatzebra.com.au/'
      self.display_name = 'Fat Zebra'
    
      # Setup a new instance of the gateway.
      #
      # The options hash should include :username and :token
      # You can find your username and token at https://dashboard.fatzebra.com.au
      # Under the Your Account section
      def initialize(options = {})
        requires!(options, :username)
        requires!(options, :token)
        @username = options[:username]
        @token    = options[:token]
        super
      end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash_or_token, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_customer(post, options)
        post[:description] = options[:description] || options[:email]
        add_flags(post, options)

        meta = generate_meta(options)

        raise ArgumentError.new("Customer or Credit Card required.") if !post[:card] && !post[:customer]

        commit(:post, 'charges', post, meta)
      end

      private
      def headers
        {
          "Authorization" => "Basic " + Base64.encode64(@username.to_s + ":" + @token.to_s).strip,
          "User-Agent" => "Fat Zebra v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end 
    end
  end
end