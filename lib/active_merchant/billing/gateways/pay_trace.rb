module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTraceGateway < Gateway
      self.test_url = 'https://api.paytrace.com'
      self.live_url = 'https://api.paytrace.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://paytrace.com/'
      self.display_name = 'PayTrace'

      # Response codes based on API Response Codes found here: https://developers.paytrace.com/support/home#14000041297
      STANDARD_ERROR_CODE_MAPPING = {
        '1'   => STANDARD_ERROR_CODE[:error_occurred],
        '102' => STANDARD_ERROR_CODE[:declined],
        '103' => STANDARD_ERROR_CODE[:auto_voided],
        '107' => STANDARD_ERROR_CODE[:unsuccessful_refund],
        '108' => STANDARD_ERROR_CODE[:test_refund],
        '110' => STANDARD_ERROR_CODE[:unsuccessful_void],
        '113' => STANDARD_ERROR_CODE[:unsuccessful_capture]
      }

      ENDPOINTS = {
        customer_id_sale: 'transactions/sale/by_customer',
        keyed_sale: 'transactions/sale/keyed',
        customer_id_auth: 'transactions/authorization/by_customer',
        keyed_auth: 'transactions/authorization/keyed',
        capture: 'transactions/authorization/capture',
        transaction_refund: 'transactions/refund/for_transaction',
        transaction_void: 'transactions/void',
        store: 'customer/create',
        redact: 'customer/delete'
      }

      def initialize(options = {})
        requires!(options, :username, :password, :integrator_id)
        super
        acquire_access_token
      end

      def purchase(money, payment_or_customerid, options = {})
        post = {}
        add_invoice(post, money, options)
        if payment_or_customerid.class == String
          post[:customer_id] = payment_or_customerid

          response = commit(ENDPOINTS[:customer_id_sale], post)
          check_token_response(response, ENDPOINTS[:customer_id_sale], post, options)
        else
          add_payment(post, payment_or_customerid)
          add_address(post, payment_or_customerid, options)
          add_customer_data(post, options)

          response = commit(ENDPOINTS[:keyed_sale], post)
          check_token_response(response, ENDPOINTS[:keyed_sale], post, options)
        end
      end

      def authorize(money, payment_or_customerid, options = {})
        post = {}
        add_invoice(post, money, options)
        if payment_or_customerid.class == String
          post[:customer_id] = payment_or_customerid

          response = commit(ENDPOINTS[:customer_id_auth], post)
          check_token_response(response, ENDPOINTS[:customer_id_auth], post, options)
        else
          add_payment(post, payment_or_customerid)
          add_address(post, payment_or_customerid, options)
          add_customer_data(post, options)

          response = commit(ENDPOINTS[:keyed_auth], post)
          check_token_response(response, ENDPOINTS[:keyed_auth], post, options)
        end
      end

      def capture(authorization, options = {})
        post = {}
        post[:amount] = amount(options[:amount]) if options[:amount]
        post[:transaction_id] = authorization
        response = commit(ENDPOINTS[:capture], post)
        check_token_response(response, ENDPOINTS[:capture], post, options)
      end

      def refund(authorization, options = {})
        # currently only support full and partial refunds of settled transactions via a transaction ID
        post = {}
        post[:amount] = amount(options[:amount]) if options[:amount]
        post[:transaction_id] = authorization
        response = commit(ENDPOINTS[:transaction_refund], post)
        check_token_response(response, ENDPOINTS[:transaction_refund], post, options)
      end

      def void(authorization, options = {})
        post = {}
        post[:transaction_id] = authorization

        response = commit(ENDPOINTS[:transaction_void], post)
        check_token_response(response, ENDPOINTS[:transaction_void], post, options)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # The customer_IDs that come from storing cards can be used for auth and purchase transaction types
      def store(credit_card, options = {})
        post = {}
        post[:customer_id] = options[:customer_id] || SecureRandom.hex(12)
        add_payment(post, credit_card)
        add_address(post, credit_card, options)
        response = commit(ENDPOINTS[:store], post)
        check_token_response(response, ENDPOINTS[:store], post, options)
      end

      def redact(customer_id)
        post = {}
        post[:customer_id] = customer_id
        response = commit(ENDPOINTS[:redact], post)
        check_token_response(response, ENDPOINTS[:redact], post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )[a-zA-Z0-9:_]+), '\1[FILTERED]').
          gsub(%r(("credit_card\\?":{\\?"number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("username\\?":\\?")\w+@+\w+.+\w+), '\1[FILTERED]').
          gsub(%r(("password\\?":\\?")\w+), '\1[FILTERED]').
          gsub(%r(("integrator_id\\?":\\?")\w+), '\1[FILTERED]')
      end

      def acquire_access_token
        post = {}
        post[:grant_type] = 'password'
        post[:username] = @options[:username]
        post[:password] = @options[:password]
        data = post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
        url = live_url + '/oauth/token'
        oauth_headers = {
          'Accept'            => '*/*',
          'Content-Type'      => 'application/x-www-form-urlencoded'
        }
        response = ssl_post(url, data, oauth_headers)
        json_response = JSON.parse(response)

        @options[:access_token] = json_response['access_token'] if json_response['access_token']
        response
      end

      private

      def add_customer_data(post, options)
        return unless options[:email]

        post[:email] = options[:email]
      end

      def add_address(post, creditcard, options)
        return unless options[:billing_address] || options[:address]

        address = options[:billing_address] || options[:address]
        post[:billing_address] = {}
        post[:billing_address][:name] = creditcard.name
        post[:billing_address][:street_address] = address[:address1]
        post[:billing_address][:city] = address[:city]
        post[:billing_address][:state] = address[:state]
        post[:billing_address][:zip] = address[:zip]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
      end

      def add_payment(post, payment)
        post[:credit_card] = {}
        post[:credit_card][:number] = payment.number
        post[:credit_card][:expiration_month] = payment.month
        post[:credit_card][:expiration_year] = payment.year
      end

      def check_token_response(response, endpoint, body = {}, options = {})
        return response unless response.params['error'] == 'invalid_token'

        acquire_access_token
        commit(endpoint, body)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        base_url = (test? ? test_url : live_url)
        url = base_url + '/v1/' + action
        raw_response = ssl_post(url, post_data(parameters), headers)
        response = parse(raw_response)
        success = success_from(response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['avs_response']),
          cvv_result: response['csc_response'],
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )
      rescue JSON::ParserError
        unparsable_response(raw_response)
      end

      def unparsable_response(raw_response)
        message = 'Unparsable response received from PayTrace. Please contact PayTrace if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      def headers
        {
          'Content-type' => 'application/json',
          'Authorization' => 'Bearer ' + @options[:access_token]
        }
      end

      def success_from(response)
        response['success']
      end

      def message_from(response)
        response['status_message']
      end

      def authorization_from(response)
        response['transaction_id']
      end

      def post_data(parameters = {})
        parameters[:password] = @options[:password]
        parameters[:username] = @options[:username]
        parameters[:integrator_id] = @options[:integrator_id]

        parameters.to_json
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['response_code']]
      end

      def handle_response(response)
        response.body
      end
    end
  end
end
