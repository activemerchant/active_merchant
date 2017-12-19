module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ZuoraGateway < Gateway
      self.test_url = 'https://rest.apisandbox.zuora.com/v1/'
      self.live_url = 'https://rest.zuora.com/v1/'

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.zuora.com/'
      self.display_name = 'Zuora'

      CARD_BRAND_MAP = {
        'visa'              => 'Visa',
        'mastercard'        => 'Mastercard',
        'american_express'  => 'AmericanExpress',
        'discover'          => 'Discover'
      }.freeze

      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      def store(credit_card, options = {})
        post = {}
        add_address(post, options)
        add_payment(post, credit_card, options)
        add_store_options(post, options)
        commit('accounts', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((apiAccessKeyId: )[^\s\\]+)i, '\1[FILTERED]').
          gsub(%r((apiSecretAccessKey: )[^\s\\]+)i, '\1[FILTERED]').
          gsub(%r((cardNumber\\\":\\\")\d+)i, '\1[FILTERED]').
          gsub(%r((securityCode\\\":\\\")\d+)i, '\1[FILTERED]')
      end

      private

      def add_address(post, options)
        if (address = (options[:billing_address] || options[:address]))
          post[:billToContact] = {
            address1: address[:address1],
            city: address[:city],
            state: address[:state],
            zipCode: address[:zip],
            country: address[:country],
            workEmail: options[:email],
            firstName: options[:first_name],
            lastName: options[:last_name]
          }.reject { |_, v| v.blank? }
        end
      end

      def add_payment(post, payment, options = {})
        if payment.respond_to?(:number)
          post[:currency] = options[:currency]
          post[:creditCard] = {
            cardNumber: payment.number,
            cardType: CARD_BRAND_MAP.fetch(payment.brand),
            expirationMonth: format(payment.month, :two_digits),
            expirationYear: format(payment.year, :four_digits),
            securityCode: payment.verification_value
          }.reject { |_, v| v.blank? }
        end
      end

      def add_store_options(post, options = {})
        post[:autoPay] = true
        post[:billCycleDay] = 0
        post[:invoiceDeliveryPrefsEmail] = options[:email].present?
        post[:invoiceDeliveryPrefsPrint] = false
        post[:name] = options[:description]
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def url(action)
        base_url = test? ? test_url : live_url

        base_url + action
      end

      def api_request(action, parameters, options = {})
        raw_response = response = nil
        begin
          raw_response = ssl_post(url(action), parameters.to_json, headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(action, parameters, options = {})
        response = api_request(action, parameters, options)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers
        headers = {
          'Content-Type'       => 'application/json',
          'User-Agent'         => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'apiAccessKeyId'     => @options[:username],
          'apiSecretAccessKey' => @options[:password]
        }

        headers
      end

      def success_from(response)
        response['success']
      end

      def message_from(response)
        return response['reasons'].map { |e| e['message'] }.join(', ') unless success_from(response)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Zuora API.  Please contact Zuora support if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'reasons' => [{
            'code' => '50000000',
            'message' => msg
          }]
        }
      end

      def authorization_from(action, response)
        case action
        when 'accounts'
          response['accountId']
        end
      end

      def error_code_from(response)
        return response['reasons'].map { |e| e['code'] }.join(', ') unless success_from(response)
      end
    end
  end
end
