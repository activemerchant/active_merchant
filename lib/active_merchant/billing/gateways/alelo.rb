require 'jose'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AleloGateway < Gateway
      self.test_url = 'https://sandbox-api.alelo.com.br/alelo/sandbox/'
      self.live_url = 'https://desenvolvedor.alelo.com.br'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.alelo.com.br'
      self.display_name = 'Alelo'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options); end

      def add_address(post, creditcard, options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment); end

      def access_token(options = {})
        return options[:access_token] if options[:access_token].present?

        params = {
          grant_type: 'client_credentials',
          client_id: @options[:client_id],
          client_secret: @options[:client_secret],
          scope: '/capture'
        }

        headers = {
          'Accept' => 'application/json',
          'Content-Type' => 'application/x-www-form-urlencoded'
        }

        raw_response = ssl_post(url('captura-oauth-provider/oauth/token'), post_data(params), headers)
        options[:access_token] = parse(raw_response)[:access_token]
      end

      def remote_encryption_key(options = {}, try_again = true)
        return options[:encryption_key] if options[:encryption_key].present?

        raw_response = ssl_get(url('capture/key?format=json'), request_headers(options))
        options[:encryption_key] = parse(raw_response)[:publicKey]
      rescue ResponseError => error
        if error.response.code == '401'
          options.delete(:access_token)
          remote_encryption_key(options, false) if try_again
        end
      end

      def encrypt_payload(body, encryption_key)
        key = OpenSSL::PKey::RSA.new(Base64.decode64(encryption_key))
        jwk = JOSE::JWK.from_key(key)
        JOSE::JWE.block_encrypt(jwk, body.to_json, { 'alg' => 'RSA-OAEP-256', 'enc' => 'A128CBC-HS256' }).compact
      end

      def parse(body)
        JSON.parse(body, symbolize_names: true)
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response); end

      def message_from(response); end

      def authorization_from(response); end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def url(action)
        "#{test? ? test_url : live_url}#{action}"
      end

      def request_headers(options)
        {
          'Accept' => 'application/json',
          'X-IBM-Client-Id' => @options[:client_id],
          'X-IBM-Client-Secret' => @options[:client_secret],
          'Authorization' => "Bearer #{options[:access_token] || access_token}"
        }
      end
    end
  end
end
