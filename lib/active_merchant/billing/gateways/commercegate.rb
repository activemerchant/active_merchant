module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CommercegateGateway < Gateway
      self.test_url = self.live_url = 'https://secure.commercegate.com/gateway/nvp'

      self.supported_countries = %w(
        AD AT AX BE BG CH CY CZ DE DK ES FI FR GB GG
        GI GR HR HU IE IM IS IT JE LI LT LU LV MC MT
        NL NO PL PT RO SE SI SK VA
      )

      self.money_format = :dollars
      self.default_currency = 'EUR'
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'http://www.commercegate.com/'
      self.display_name = 'CommerceGate'

      def initialize(options = {})
        requires!(options, :login, :password, :site_id, :offer_id)
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
        post[:currencyCode] = (options[:currency] || currency(money))
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

      def add_address(post, address)
        if address
          post[:address]     = address[:address1]
          post[:city]        = address[:city]
          post[:state]       = address[:state]
          post[:postalCode]  = address[:zip]
        end
        post[:countryCode] = ((address && address[:country]) || 'US')
      end

      def add_auth_purchase_options(post, money, options)
        add_address(post, options[:address])

        post[:customerIP]  = options[:ip] || '127.0.0.1'
        post[:amount]      = amount(money)
        post[:email]       = options[:email] || 'unknown@example.com'
        post[:currencyCode] = options[:currency] || currency(money)
        post[:merchAcct] = options[:merchant]
      end

      def add_creditcard(params, creditcard)
        params[:firstName]   = creditcard.first_name
        params[:lastName]    = creditcard.last_name
        params[:cardNumber]  = creditcard.number
        params[:expiryMonth] = creditcard.month
        params[:expiryYear]  = creditcard.year
        params[:cvv]         = creditcard.verification_value if creditcard.verification_value?
      end

      def commit(action, parameters)
        parameters[:apiUsername] = @options[:login]
        parameters[:apiPassword] = @options[:password]
        parameters[:siteID]      = @options[:site_id]
        parameters[:offerID]     = @options[:offer_id]
        parameters[:action]      = action

        response = parse(ssl_post(self.live_url, post_data(parameters)))

        Response.new(
          successful?(response),
          message_from(response),
          response,
          authorization: response['transID'],
          test: test?,
          avs_result: {code: response['avsCode']},
          cvv_result: response['cvvCode']
        )
      end

      def parse(body)
        results = {}

        body.split(/\&/).each do |pair|
          key, val = pair.split(%r{=})
          results[key] = CGI.unescape(val)
        end

        results
      end

      def successful?(response)
        response['returnCode'] == '0'
      end

      def message_from(response)
        if response['returnText'].present?
          response['returnText']
        else
          'Invalid response received from the CommerceGate API. ' \
          'Please contact CommerceGate support if you continue to receive this message. ' \
          "(The raw response returned by the API was #{response.inspect})"
        end
      end

      def post_data(parameters)
        parameters.collect do |key, value|
          "#{key}=#{CGI.escape(value.to_s)}"
        end.join('&')
      end
    end
  end
end
