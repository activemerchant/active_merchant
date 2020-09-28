module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BanwireGateway < Gateway
      URL = 'https://banwire.com/api.pago_pro'

      self.supported_countries = ['MX']
      self.supported_cardtypes = %i[visa master american_express]
      self.homepage_url = 'http://www.banwire.com/'
      self.display_name = 'Banwire'

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_response_type(post)
        add_customer_data(post, options)
        add_order_data(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)

        commit(money, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?card_num=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?card_ccv2=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_response_type(post)
        post[:response_format] = 'JSON'
      end

      def add_customer_data(post, options)
        post[:user] = @options[:login]
        post[:phone] = options[:billing_address][:phone]
        post[:mail] = options[:email] || 'unspecified@email.com'
      end

      def add_order_data(post, options)
        post[:reference] = options[:order_id] || generate_unique_id
        post[:concept] = options[:description]
      end

      def add_address(post, creditcard, options)
        post[:address] = options[:billing_address][:address1]
        post[:post_code] = options[:billing_address][:zip]
      end

      def add_creditcard(post, creditcard)
        post[:card_num] = creditcard.number
        post[:card_name] = creditcard.name
        post[:card_type] = card_brand(creditcard)
        post[:card_exp] = "#{sprintf('%02d', creditcard.month)}/#{creditcard.year.to_s[-2, 2]}"
        post[:card_ccv2] = creditcard.verification_value
      end

      def add_amount(post, money, options)
        post[:ammount] = amount(money)
        post[:currency] = options[:currency]
      end

      def card_brand(card)
        brand = super
        ({'master' => 'mastercard', 'american_express' => 'amex'}[brand] || brand)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(money, parameters)
        raw_response = ssl_post(URL, post_data(parameters))
        begin
          response = parse(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        Response.new(success?(response),
          response['message'],
          response,
          test: test?,
          authorization: response['code_auth'])
      end

      def success?(response)
        (response['response'] == 'ok')
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Banwire API.  Please contact Banwire support if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'message' => msg
        }
      end
    end
  end
end
