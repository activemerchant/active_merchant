module ActiveMerchant #:nodoc:

  module Billing #:nodoc:
    class CommercegateGateway < Gateway
      self.test_url = self.live_url = 'https://secure.commercegate.com/gateway/nvp'

      self.supported_countries = %w(AD AE AT AU BA BE BG BN CA CH CY CZ DE DK EE EG ES FI FR GB
                                    GI GL GR HK HR HU ID IE IL IM IN IS IT LI LK LT LU LV MC MT
                                    MU MV MX MY NL NO NZ PH PL PT QA RO RU SA SE SG SI SK SM TR
                                    UA UM US VA)
      self.money_format = :dollars
      self.default_currency = 'EUR'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.commercegate.com/'

      # The name of the gateway
      self.display_name = 'CommerceGate'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_auth_purchase_options(post, money, options)
        commit('AUTH', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:currencyCode] = options[:currency] || currency(money)
        post[:amount] = amount(money)
        post[:transID] = authorization
        commit('CAPTURE', post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_auth_purchase_options(post, money, options)
        commit('SALE', post)
      end

      def refund(money, identification, options = {})
        post = {}
        post[:currencyCode] = options[:currency] || currency(money)
        post[:amount] = amount(money)
        post[:transID] = identification
        commit('REFUND', post)
      end

      def void(identification, options = {})
        post = {}
        post[:transID] = identification
        commit('VOID_AUTH', post)
      end

      private

      def add_gateway_specific_options(post, options)
        post[:siteID]  = options[:site_id]
        post[:offerID] = options[:offer_id]
      end

      def add_address(post, address)
        post[:address]     = address[:address1]
        post[:city]        = address[:city]
        post[:state]       = address[:state]
        post[:postalCode]  = address[:zip]
        post[:countryCode] = address[:country]
      end

      def add_auth_purchase_options(post, money, options)
        add_address(post, options[:address])
        add_gateway_specific_options(post, options)

        post[:customerIP]  = options[:ip]
        post[:amount]      = amount(money)
        post[:email]       = options[:email]
        post[:currencyCode]= options[:currency] || currency(money)
        post[:merchAcct]   = options[:merchant]

      end

      def add_creditcard(params, creditcard)
        params[:firstName]   = creditcard.first_name
        params[:lastName]    = creditcard.last_name
        params[:cardNumber]  = creditcard.number
        params[:expiryMonth] = creditcard.month
        params[:expiryYear]  = creditcard.year
        params[:cvv]         = creditcard.verification_value if creditcard.verification_value?
      end

      def parse(body)
        results = {}

        body.split(/\&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = CGI.unescape(val)
        end

        results
      end

      def commit(action, parameters)
        parameters[:apiUsername] = @options[:login]
        parameters[:apiPassword] = @options[:password]
        parameters[:action]      = action
        begin
          response = parse(ssl_post(self.live_url, post_data(parameters)))
        rescue ResponseError => e
          response = parse_error_response(e, action)
        end

        options = {
          :authorization => response['transID'],
          :test => test?,
          :avs_result => { :code => response['avsCode'] },
          :cvv_result => response['cvvCode']
        }
        Response.new(successful?(response), message_from(response), response, options)
      end

      def parse_error_response(response_error, action)
        response = {:action => action, :returnCode => '-1', :returnText => response_error}
      end

      def successful?(response)
        response['returnCode'] == '0'
      end

      def message_from(response)
        if response['returnText'].present?
          response['returnText']
        else
          "Invalid response received from the CommerceGate API. Please contact CommerceGate support if you continue to receive this message. (The raw response returned by the API was #{response.inspect})"
        end
      end

      def post_data(parameters)
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
