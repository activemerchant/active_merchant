module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickbooksGateway < Gateway
      self.test_url = 'https://sandbox.api.intuit.com'
      self.live_url = 'https://api.intuit.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners]

      self.homepage_url = 'http://payments.intuit.com'
      self.display_name = 'QuickBooks Payments'
      BASE = '/quickbooks/v4/payments'
      ENDPOINT = "#{BASE}/charges"
      VOID_ENDPOINT = "#{BASE}/txn-requests"
      REFRESH_URI = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'

      # https://developer.intuit.com/docs/0150_payments/0300_developer_guides/error_handling

      STANDARD_ERROR_CODE_MAPPING = {
        # Fraud Warnings
        'PMT-1000' => STANDARD_ERROR_CODE[:processing_error],   # payment was accepted, but refund was unsuccessful
        'PMT-1001' => STANDARD_ERROR_CODE[:invalid_cvc],        # payment processed, but cvc was invalid
        'PMT-1002' => STANDARD_ERROR_CODE[:incorrect_address],  # payment processed, incorrect address info
        'PMT-1003' => STANDARD_ERROR_CODE[:processing_error],   # payment processed, address info couldn't be validated

        # Fraud Errors
        'PMT-2000' => STANDARD_ERROR_CODE[:incorrect_cvc],      # Incorrect CVC
        'PMT-2001' => STANDARD_ERROR_CODE[:invalid_cvc],        # CVC check unavaliable
        'PMT-2002' => STANDARD_ERROR_CODE[:incorrect_address],  # Incorrect address
        'PMT-2003' => STANDARD_ERROR_CODE[:incorrect_address],  # Address info unavailable

        'PMT-3000' => STANDARD_ERROR_CODE[:processing_error],   # Merchant account could not be validated

        # Invalid Request
        'PMT-4000' => STANDARD_ERROR_CODE[:processing_error],   # Object is invalid
        'PMT-4001' => STANDARD_ERROR_CODE[:processing_error],   # Object not found
        'PMT-4002' => STANDARD_ERROR_CODE[:processing_error],   # Object is required

        # Transaction Declined
        'PMT-5000' => STANDARD_ERROR_CODE[:card_declined],      # Request was declined
        'PMT-5001' => STANDARD_ERROR_CODE[:card_declined],      # Merchant does not support given payment method

        # System Error
        'PMT-6000' => STANDARD_ERROR_CODE[:processing_error], # A temporary Issue prevented this request from being processed.
      }

      FRAUD_WARNING_CODES = ['PMT-1000', 'PMT-1001', 'PMT-1002', 'PMT-1003']

      def initialize(options = {})
        # Quickbooks is deprecating OAuth 1.0 on December 17, 2019.
        # OAuth 2.0 requires a client_id, client_secret, access_token, and refresh_token
        # To maintain backwards compatibility, check for the presence of a refresh_token (only specified for OAuth 2.0)
        # When present, validate that all OAuth 2.0 options are present
        if options[:refresh_token]
          requires!(options, :client_id, :client_secret, :access_token, :refresh_token)
        else
          requires!(options, :consumer_key, :consumer_secret, :access_token, :token_secret, :realm)
        end
        @options = options
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_amount(post, money, options)
        add_charge_data(post, payment, options)
        post[:capture] = 'true'

        response = commit(ENDPOINT, post)
        check_token_response(response, ENDPOINT, post, options)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_amount(post, money, options)
        add_charge_data(post, payment, options)
        post[:capture] = 'false'

        response = commit(ENDPOINT, post)
        check_token_response(response, ENDPOINT, post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        authorization, = split_authorization(authorization)
        post[:amount] = localized_amount(money, currency(money))
        add_context(post, options)

        response = commit(capture_uri(authorization), post)
        check_token_response(response, capture_uri(authorization), post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:amount] = localized_amount(money, currency(money))
        add_context(post, options)
        authorization, = split_authorization(authorization)

        response = commit(refund_uri(authorization), post)
        check_token_response(response, refund_uri(authorization), post, options)
      end

      def void(authorization, options = {})
        _, request_id = split_authorization(authorization)

        response = commit(void_uri(request_id))
        check_token_response(response, void_uri(request_id), {}, options)
      end

      def verify(credit_card, options = {})
        authorize(1.00, credit_card, options)
      end

      def refresh
        response = refresh_access_token
        response_object(response)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((realm=\")\w+), '\1[FILTERED]').
          gsub(%r((oauth_consumer_key=\")\w+), '\1[FILTERED]').
          gsub(%r((oauth_nonce=\")\w+), '\1[FILTERED]').
          gsub(%r((oauth_signature=\")[a-zA-Z%0-9]+), '\1[FILTERED]').
          gsub(%r((oauth_token=\")\w+), '\1[FILTERED]').
          gsub(%r((number\D+)\d{16}), '\1[FILTERED]').
          gsub(%r((cvc\D+)\d{3}), '\1[FILTERED]').
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((access_token\\?":\\?")[\w\-\.]+)i, '\1[FILTERED]').
          gsub(%r((refresh_token\\?":\\?")\w+), '\1[FILTERED]').
          gsub(%r((refresh_token=)\w+), '\1[FILTERED]').
          gsub(%r((Authorization: Bearer )[\w\-\.]+)i, '\1[FILTERED]\2')
      end

      private

      def add_charge_data(post, payment, options = {})
        add_payment(post, payment, options)
        add_address(post, options)
      end

      def add_address(post, options)
        return unless post[:card]&.kind_of?(Hash)

        card_address = {}
        if address = options[:billing_address] || options[:address]
          card_address[:streetAddress] = address[:address1]
          card_address[:city] = address[:city]
          region = address[:state] || address[:region]
          card_address[:region] = region if region.present?
          card_address[:country] = address[:country] if address[:country].present?
          card_address[:postalCode] = address[:zip] if address[:zip]
        end
        post[:card][:address] = card_address
      end

      def add_amount(post, money, options = {})
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.upcase
      end

      def add_payment(post, payment, options = {})
        add_creditcard(post, payment, options)
        add_context(post, options)
      end

      def add_creditcard(post, creditcard, options = {})
        card = {}
        card[:number] = creditcard.number
        card[:expMonth] = '%02d' % creditcard.month
        card[:expYear] = creditcard.year
        card[:cvc] = creditcard.verification_value if creditcard.verification_value?
        card[:name] = creditcard.name if creditcard.name
        card[:commercialCardCode] = options[:card_code] if options[:card_code]

        post[:card] = card
      end

      def add_context(post, options = {})
        post[:context] = {
          mobile: options.fetch(:mobile, false),
          isEcommerce: options.fetch(:ecommerce, true)
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(uri, body = {}, method = :post)
        endpoint = gateway_url + uri
        # The QuickBooks API returns HTTP 4xx on failed transactions, which causes a
        # ResponseError raise, so we have to inspect the response and discern between
        # a legitimate HTTP error and an actual gateway transactional error.
        headers = {}
        response =
          begin
            headers = headers(method, endpoint)
            method == :post ? ssl_post(endpoint, post_data(body), headers) : ssl_request(:get, endpoint, nil, headers)
          rescue ResponseError => e
            extract_response_body_or_raise(e)
          end

        response_object(response, headers)
      end

      def response_object(raw_response, headers = {})
        parsed_response = parse(raw_response)

        # Include access_token and refresh_token in params for OAuth 2.0
        parsed_response['access_token'] = @options[:access_token] if @options[:refresh_token]
        parsed_response['refresh_token'] = @options[:refresh_token] if @options[:refresh_token]

        Response.new(
          success?(parsed_response),
          message_from(parsed_response),
          parsed_response,
          authorization: authorization_from(parsed_response, headers),
          test: test?,
          cvv_result: cvv_code_from(parsed_response),
          error_code: errors_from(parsed_response),
          fraud_review: fraud_review_status_from(parsed_response)
        )
      end

      def gateway_url
        test? ? test_url : live_url
      end

      def post_data(data = {})
        data.to_json
      end

      def headers(method, uri)
        return oauth_v2_headers if @options[:refresh_token]

        raise ArgumentError, "Invalid HTTP method: #{method}. Valid methods are :post and :get" unless %i[post get].include?(method)

        request_uri = URI.parse(uri)

        # Following the guidelines from http://nouncer.com/oauth/authentication.html
        oauth_parameters = {
          oauth_nonce: generate_unique_id,
          oauth_timestamp: Time.now.to_i.to_s,
          oauth_signature_method: 'HMAC-SHA1',
          oauth_version: '1.0',
          oauth_consumer_key: @options[:consumer_key],
          oauth_token: @options[:access_token]
        }

        # prepare components for signature
        oauth_signature_base_string = [method.to_s.upcase, request_uri.to_s, oauth_parameters.to_param].map { |v| CGI.escape(v) }.join('&')
        oauth_signing_key = [@options[:consumer_secret], @options[:token_secret]].map { |v| CGI.escape(v) }.join('&')
        hmac_signature = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), oauth_signing_key, oauth_signature_base_string)

        # append signature to required OAuth parameters
        oauth_parameters[:oauth_signature] = CGI.escape(Base64.encode64(hmac_signature).chomp.gsub(/\n/, ''))

        # prepare Authorization header string
        oauth_parameters = Hash[oauth_parameters.sort_by { |k, _| k }]
        oauth_headers = ["OAuth realm=\"#{@options[:realm]}\""]
        oauth_headers += oauth_parameters.map { |k, v| "#{k}=\"#{v}\"" }

        {
          'Content-type' => 'application/json',
          'Request-Id' => generate_unique_id,
          'Authorization' => oauth_headers.join(', ')
        }
      end

      def oauth_v2_headers
        {
          'Content-Type'      => 'application/json',
          'Request-Id'        => generate_unique_id,
          'Accept'            => 'application/json',
          'Authorization'     => "Bearer #{@options[:access_token]}"
        }
      end

      def check_token_response(response, endpoint, body = {}, options = {})
        return response unless @options[:refresh_token]
        return response unless options[:allow_refresh]
        return response unless response.params['code'] == 'AuthenticationFailed'

        refresh_access_token
        commit(endpoint, body)
      end

      def refresh_access_token
        post = {}
        post[:grant_type] = 'refresh_token'
        post[:refresh_token] = @options[:refresh_token]
        data = post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')

        basic_auth = Base64.strict_encode64("#{@options[:client_id]}:#{@options[:client_secret]}")
        headers = {
          'Content-Type'      => 'application/x-www-form-urlencoded',
          'Accept'            => 'application/json',
          'Authorization'     => "Basic #{basic_auth}"
        }

        response = ssl_post(REFRESH_URI, data, headers)
        json_response = JSON.parse(response)

        @options[:access_token] = json_response['access_token'] if json_response['access_token']
        @options[:refresh_token] = json_response['refresh_token'] if json_response['refresh_token']
        response
      end

      def cvv_code_from(response)
        if response['errors'].present?
          FRAUD_WARNING_CODES.include?(response['errors'].first['code']) ? 'I' : ''
        else
          success?(response) ? 'M' : ''
        end
      end

      def success?(response)
        return FRAUD_WARNING_CODES.concat(['0']).include?(response['errors'].first['code']) if response['errors']

        !%w[DECLINED CANCELLED].include?(response['status']) && !%w[AuthenticationFailed AuthorizationFailed].include?(response['code'])
      end

      def message_from(response)
        response['errors'].present? ? response['errors'].map { |error_hash| error_hash['message'] }.join(' ') : response['status']
      end

      def errors_from(response)
        if %w[AuthenticationFailed AuthorizationFailed].include?(response['code'])
          response['code']
        else
          response['errors'].present? ? STANDARD_ERROR_CODE_MAPPING[response['errors'].first['code']] : ''
        end
      end

      def authorization_from(response, headers = {})
        [response['id'], headers['Request-Id']].join('|')
      end

      def split_authorization(authorization)
        authorization, request_id = authorization.split('|')
        [authorization, request_id]
      end

      def fraud_review_status_from(response)
        response['errors'] && FRAUD_WARNING_CODES.include?(response['errors'].first['code'])
      end

      def extract_response_body_or_raise(response_error)
        begin
          parse(response_error.response.body)
        rescue JSON::ParserError
          raise response_error
        end
        response_error.response.body
      end

      def refund_uri(authorization)
        "#{ENDPOINT}/#{CGI.escape(authorization.to_s)}/refunds"
      end

      def capture_uri(authorization)
        "#{ENDPOINT}/#{CGI.escape(authorization.to_s)}/capture"
      end

      def void_uri(request_id)
        "#{VOID_ENDPOINT}/#{CGI.escape(request_id.to_s)}/void"
      end
    end
  end
end
