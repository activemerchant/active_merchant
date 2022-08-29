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

      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_order(post, options)
        add_amount(post, money)
        add_payment(post, payment, options)
        add_geolocation(post, options)
        add_extra_data(post, options)

        commit('capture/transaction', post, options)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        force_utf8(transcript.encode).
          gsub(%r((Authorization: Bearer )[\w -]+), '\1[FILTERED]').
          gsub(%r((client_id=|Client-Id:)[\w -]+), '\1[FILTERED]\2').
          gsub(%r((client_secret=|Client-Secret:)[\w -]+), '\1[FILTERED]\2')
      end

      private

      def force_utf8(string)
        return nil unless string

        # Needed for Ruby 2.0 since #encode is a no-op if the string is already UTF-8.
        # It's not needed for Ruby 2.1 and up since it's not a no-op there.
        binary = string.encode('BINARY', invalid: :replace, undef: :replace, replace: '?')
        binary.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_order(post, options)
        post[:request_id] = options[:order_id]
      end

      def add_extra_data(post, options)
        post.merge!({
          establishmentCode: options[:establishment_code],
          playerIdentification: options[:player_identification],
          captureType: '3', # send fixed value 3 to ecommerce
          subMerchantCode: options[:sub_merchant_mcc],
          externalTraceNumber: options[:external_trace_number]
        }.compact)
      end

      def add_geolocation(post, options)
        return if options[:geolocation].blank?

        post.merge!(geolocation: {
          latitude: options[:geolocation][:latitude],
          longitude: options[:geolocation][:longitude]
        })
      end

      def add_payment(post, payment, options)
        post.merge!({
          cardNumber: payment.number,
          cardholderName: payment.name,
          expirationMonth: payment.month,
          expirationYear: format(payment.year, :two_digits),
          securityCode: payment.verification_value
        })
      end

      def fetch_access_token
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

        parsed = parse(raw_response)
        Response.new(true, parsed[:access_token], parsed)
      end

      def remote_encryption_key(access_token)
        response = parse(ssl_get(url('capture/key?format=json'), request_headers(access_token)))
        Response.new(true, response[:publicKey], response)
      end

      def ensure_credentials(options, try_again = true)
        multiresp = MultiResponse.new
        access_token = options[:access_token]
        key = options[:encryption_key]

        if access_token.blank?
          multiresp.process { fetch_access_token }
          access_token = multiresp.message
          key = nil
        end

        if key.blank?
          multiresp.process { remote_encryption_key(access_token) }
          key = multiresp.message
        end

        {
          key: key,
          access_token: access_token,
          multiresp: multiresp.responses.present? ? multiresp : nil
        }
      rescue ResponseError => error
        # retry generating a new access_token when the provided one is expired
        raise error unless try_again && error.response.code == '401' && options[:access_token].present?

        options.delete(:access_token)
        options.delete(:encryption_key)
        ensure_credentials(options, false)
      end

      def encrypt_payload(body, options)
        credentials = ensure_credentials(options)
        key = OpenSSL::PKey::RSA.new(Base64.decode64(credentials[:key]))
        jwk = JOSE::JWK.from_key(key)
        alg_enc = { 'alg' => 'RSA-OAEP-256', 'enc' => 'A128CBC-HS256' }

        token = JOSE::JWE.block_encrypt(jwk, body.to_json, alg_enc).compact

        encrypted_body = {
          token: token,
          uuid: options[:uuid] || SecureRandom.uuid
        }

        return encrypted_body.to_json, credentials
      end

      def parse(body)
        JSON.parse(body, symbolize_names: true)
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def commit(action, body, options, try_again = true)
        payload, credentials = encrypt_payload(body, options)
        response = parse(ssl_post(url(action), payload, request_headers(credentials[:access_token])))

        resp = Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?
        )

        return resp unless credentials[:multiresp].present?

        multiresp = credentials[:multiresp]
        # put code to send back GSF back to the merchant if is needed
        multiresp.process { resp }
        multiresp
      rescue ActiveMerchant::ResponseError => e
        # Retry on a possible expired encryption key
        if try_again && e.response.code == '401' && options[:encryption_key].present?
          options.delete(:access_token)
          options.delete(:encryption_key)
          commit(action, body, options, false)
        else
          res = parse(e.response.body)
          Response.new(false, res[:messageUser] || res[:error], res, test: test?)
        end
      end

      def success_from(response)
        response[:status] == 'CONFIRMADA'
      end

      def message_from(response)
        response[:messages] || response[:messageUser]
      end

      def authorization_from(response)
        [response['requestId'], response['authorizationCode']].join('#')
      end

      def url(action)
        "#{test? ? test_url : live_url}#{action}"
      end

      def request_headers(access_token)
        {
          'Accept' => 'application/json',
          'X-IBM-Client-Id' => @options[:client_id],
          'X-IBM-Client-Secret' => @options[:client_secret],
          'Authorization' => "Bearer #{access_token}"
        }
      end
    end
  end
end
