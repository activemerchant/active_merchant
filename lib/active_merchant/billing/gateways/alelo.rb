require 'jose'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AleloGateway < Gateway
      class_attribute :prelive_url

      self.test_url = 'https://sandbox-api.alelo.com.br/alelo/sandbox/'
      self.live_url = 'https://api.alelo.com.br/alelo/prd/'
      self.prelive_url = 'https://api.homologacaoalelo.com.br/alelo/uat/'

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
        add_payment(post, payment)
        add_geolocation(post, options)
        add_extra_data(post, options)

        commit('capture/transaction', post, options)
      end

      def refund(money, authorization, options = {})
        request_id = authorization.split('#').first
        options[:http] = { method: :put, prevent_encrypt: true }
        commit('capture/transaction/refund', { requestId: request_id }, options, :put)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        force_utf8(transcript.encode).
          gsub(%r((Authorization: Bearer )[\w -]+), '\1[FILTERED]').
          gsub(%r((client_id=|Client-Id:)[\w -]+), '\1[FILTERED]\2').
          gsub(%r((client_secret=|Client-Secret:)[\w -]+), '\1[FILTERED]\2').
          gsub(%r((access_token\":\")[^\"]*), '\1[FILTERED]').
          gsub(%r((publicKey\":\")[^\"]*), '\1[FILTERED]')
      end

      private

      def force_utf8(string)
        return nil unless string

        # binary = string.encode('BINARY', invalid: :replace, undef: :replace, replace: '?')
        string.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end

      def add_amount(post, money)
        post[:amount] = amount(money).to_f
      end

      def add_order(post, options)
        post[:requestId] = options[:order_id]
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
        return if options[:geo_latitude].blank? || options[:geo_longitude].blank?

        post.merge!(geolocation: {
          latitude: options[:geo_latitude],
          longitude: options[:geo_longitude]
        })
      end

      def add_payment(post, payment)
        post.merge!({
          cardNumber: payment.number,
          cardholderName: payment.name,
          expirationMonth: payment.month,
          expirationYear: format(payment.year, :two_digits).to_i,
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

        parsed = parse(ssl_post(url('captura-oauth-provider/oauth/token'), post_data(params), headers))
        Response.new(true, parsed[:access_token], parsed)
      end

      def remote_encryption_key(access_token)
        response = parse(ssl_get(url('capture/key'), request_headers(access_token)))
        Response.new(true, response[:publicKey], response)
      end

      def ensure_credentials(try_again = true)
        multiresp = MultiResponse.new
        access_token = @options[:access_token]
        key = @options[:encryption_key]
        uuid = @options[:encryption_uuid]

        if access_token.blank?
          multiresp.process { fetch_access_token }
          access_token = multiresp.message
          key = nil
          uuid = nil
        end

        if key.blank?
          multiresp.process { remote_encryption_key(access_token) }
          key = multiresp.message
          uuid = multiresp.params['uuid']
        end

        {
          key: key,
          uuid: uuid,
          access_token: access_token,
          multiresp: multiresp.responses.present? ? multiresp : nil
        }
      rescue ResponseError => error
        # retry to generate a new access_token when the provided one is expired
        raise error unless try_again && %w(401 404).include?(error.response.code) && @options[:access_token].present?

        @options.delete(:access_token)
        @options.delete(:encryption_key)
        ensure_credentials false
      end

      def encrypt_payload(body, credentials, options)
        key = OpenSSL::PKey::RSA.new(Base64.decode64(credentials[:key]))
        jwk = JOSE::JWK.from_key(key)
        alg_enc = { 'alg' => 'RSA-OAEP-256', 'enc' => 'A128CBC-HS256' }

        token = JOSE::JWE.block_encrypt(jwk, body.to_json, alg_enc).compact

        encrypted_body = {
          token: token,
          uuid: credentials[:uuid]
        }

        encrypted_body.to_json
      end

      def parse(body)
        JSON.parse(body, symbolize_names: true)
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def commit(action, body, options, try_again = true)
        credentials = ensure_credentials
        payload = encrypt_payload(body, credentials, options)

        if options.dig :http, :method
          payload = body.to_json if options.dig :http, :prevent_encrypt
          response = parse ssl_request(options[:http][:method], url(action), payload, request_headers(credentials[:access_token]))
        else
          response = parse ssl_post(url(action), payload, request_headers(credentials[:access_token]))
        end

        resp = Response.new(
          success_from(action, response),
          message_from(response),
          response,
          authorization: authorization_from(response, options),
          test: test?
        )

        return resp unless credentials[:multiresp].present?

        multiresp = credentials[:multiresp]
        resp.params.merge!({
          'access_token' => credentials[:access_token],
          'encryption_key' => credentials[:key],
          'encryption_uuid' => credentials[:uuid]
        })
        multiresp.process { resp }

        multiresp
      rescue ActiveMerchant::ResponseError => e
        # Retry on a possible expired encryption key
        if try_again && %w(401 404).include?(e.response.code) && @options[:encryption_key].present?
          @options.delete(:encryption_key)
          commit(action, body, options, false)
        else
          res = parse(e.response.body)
          Response.new(false, res[:messageUser] || res[:error], res, test: test?)
        end
      end

      def success_from(action, response)
        case action
        when 'capture/transaction/refund'
          response[:status] == 'ESTORNADA'
        when 'capture/transaction'
          response[:status] == 'CONFIRMADA'
        else
          false
        end
      end

      def message_from(response)
        response[:messages] || response[:messageUser]
      end

      def authorization_from(response, options)
        [response[:requestId]].join('#')
      end

      def url(action)
        return prelive_url if @options[:url_override] == 'prelive'

        "#{test? ? test_url : live_url}#{action}"
      end

      def request_headers(access_token)
        {
          'Accept' => 'application/json',
          'X-IBM-Client-Id' => @options[:client_id],
          'X-IBM-Client-Secret' => @options[:client_secret],
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{access_token}"
        }
      end
    end
  end
end
