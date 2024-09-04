module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTraceGateway < Gateway
      self.test_url = 'https://api.sandbox.paytrace.com'
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
        redact: 'customer/delete',
        level_3_visa: 'level_three/visa',
        level_3_mastercard: 'level_three/mastercard',
        ach_sale: 'checks/sale/by_account',
        ach_customer_sale: 'checks/sale/by_customer',
        ach_authorize: 'checks/hold/by_account',
        ach_customer_authorize: 'checks/hold/by_customer',
        ach_refund: 'checks/refund/by_transaction',
        ach_capture: 'checks/manage/fund',
        ach_void: 'checks/manage/void'
      }

      def initialize(options = {})
        requires!(options, :username, :password, :integrator_id)
        super
        acquire_access_token unless options[:access_token]
      end

      def purchase(money, payment_or_customer_id, options = {})
        if visa_or_mastercard?(options)
          MultiResponse.run(:use_first_response) do |r|
            endpoint = customer_id?(payment_or_customer_id) ? ENDPOINTS[:customer_id_sale] : ENDPOINTS[:keyed_sale]

            r.process { commit(endpoint, build_purchase_request(money, payment_or_customer_id, options)) }
            r.process { commit(ENDPOINTS[:"level_3_#{options[:visa_or_mastercard]}"], send_level_3_data(r, options)) }
          end
        else
          post = build_purchase_request(money, payment_or_customer_id, options)
          endpoint = if payment_or_customer_id.kind_of?(Check)
                       ENDPOINTS[:ach_sale]
                     elsif options[:check_transaction]
                       ENDPOINTS[:ach_customer_sale]
                     elsif post[:customer_id]
                       ENDPOINTS[:customer_id_sale]
                     else
                       ENDPOINTS[:keyed_sale]
                     end
          response = commit(endpoint, post)
          check_token_response(response, endpoint, post, options)
        end
      end

      def authorize(money, payment_or_customer_id, options = {})
        post = {}
        add_amount(post, money, options)
        if customer_id?(payment_or_customer_id)
          post[:customer_id] = payment_or_customer_id
          endpoint = if options[:check_transaction]
                       ENDPOINTS[:ach_customer_authorize]
                     else
                       ENDPOINTS[:customer_id_auth]
                     end
        else
          add_payment(post, payment_or_customer_id)
          add_address(post, payment_or_customer_id, options)
          add_customer_data(post, options)
          endpoint = payment_or_customer_id.kind_of?(Check) ? ENDPOINTS[:ach_authorize] : ENDPOINTS[:keyed_auth]
        end
        response = commit(endpoint, post)
        check_token_response(response, endpoint, post, options)
      end

      def capture(money, authorization, options = {})
        if visa_or_mastercard?(options)
          MultiResponse.run(:use_first_response) do |r|
            r.process { commit(ENDPOINTS[:capture], build_capture_request(money, authorization, options)) }
            r.process { commit(ENDPOINTS[:"level_3_#{options[:visa_or_mastercard]}"], send_level_3_data(r, options)) }
          end
        else
          post = build_capture_request(money, authorization, options)
          endpoint = if options[:check_transaction]
                       ENDPOINTS[:ach_capture]
                     else
                       ENDPOINTS[:capture]
                     end
          response = commit(endpoint, post)
          check_token_response(response, endpoint, post, options)
        end
      end

      def refund(money, authorization, options = {})
        # currently only support full and partial refunds of settled transactions via a transaction ID
        post = {}
        add_amount(post, money, options)
        if options[:check_transaction]
          post[:check_transaction_id] = authorization
          endpoint = ENDPOINTS[:ach_refund]
        else
          post[:transaction_id] = authorization
          endpoint = ENDPOINTS[:transaction_refund]
        end
        response = commit(endpoint, post)
        check_token_response(response, endpoint, post, options)
      end

      def void(authorization, options = {})
        post = {}
        if options[:check_transaction]
          post[:check_transaction_id] = authorization
          endpoint = ENDPOINTS[:ach_void]
        else
          post[:transaction_id] = authorization
          endpoint = ENDPOINTS[:transaction_void]
        end

        response = commit(endpoint, post)
        check_token_response(response, endpoint, post, options)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
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

      def unstore(customer_id)
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
          gsub(%r(("csc\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("username\\?":\\?")\w+@+\w+.+\w+), '\1[FILTERED]').
          gsub(%r(("username\\?":\\?")\w+), '\1[FILTERED]').
          gsub(%r(("password\\?":\\?")\w+), '\1[FILTERED]').
          gsub(%r(("integrator_id\\?":\\?")\w+), '\1[FILTERED]')
      end

      def acquire_access_token
        post = {}
        base_url = (test? ? test_url : live_url)
        post[:grant_type] = 'password'
        post[:username] = @options[:username]
        post[:password] = @options[:password]
        data = post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
        url = base_url + '/oauth/token'
        oauth_headers = {
          'Accept'            => '*/*',
          'Content-Type'      => 'application/x-www-form-urlencoded'
        }
        response = ssl_post(url, data, oauth_headers)
        json_response = parse(response)

        if json_response.include?('error')
          oauth_response = Response.new(false, json_response['error_description'])
          raise OAuthResponseError.new(oauth_response)
        else
          @options[:access_token] = json_response['access_token'] if json_response['access_token']
          response
        end
      end

      private

      def build_purchase_request(money, payment_or_customer_id, options)
        post = {}
        add_amount(post, money, options)
        if customer_id?(payment_or_customer_id)
          post[:customer_id] = payment_or_customer_id
        else
          add_payment(post, payment_or_customer_id)
          add_address(post, payment_or_customer_id, options)
          add_customer_data(post, options)
        end

        post
      end

      def build_capture_request(money, authorization, options)
        post = {}
        if options[:check_transaction]
          post[:check_transaction_id] = authorization
        else
          post[:transaction_id] = authorization
        end
        add_amount(post, money, options)

        post
      end

      # method can only be used to add level 3 data to any approved and unsettled sale transaction so it is built into the standard purchase workflow above
      def send_level_3_data(response, options)
        post = {}
        post[:transaction_id] = response.authorization
        add_level_3_data(post, options)

        post
      end

      def visa_or_mastercard?(options)
        return false unless options[:visa_or_mastercard]

        options[:visa_or_mastercard] == 'visa' || options[:visa_or_mastercard] == 'mastercard'
      end

      def customer_id?(payment_or_customer_id)
        payment_or_customer_id.instance_of?(String)
      end

      def string_literal_to_boolean(value)
        return value unless value.instance_of?(String)

        if value.casecmp('true').zero?
          true
        elsif value.casecmp('false').zero?
          false
        else return nil
        end
      end

      def add_customer_data(post, options)
        return unless options[:email]

        post[:email] = options[:email]
      end

      def add_address(post, creditcard, options)
        post[:billing_address] = {}

        if (address = options[:billing_address] || options[:address])
          post[:billing_address][:street_address] = address[:address1]
          post[:billing_address][:city] = address[:city]
          post[:billing_address][:state] = address[:state]
          post[:billing_address][:zip] = address[:zip]
        end

        post[:billing_address][:name] = creditcard.name
      end

      def add_amount(post, money, options)
        post[:amount] = amount(money)
      end

      def add_payment(post, payment)
        if payment.kind_of?(Check)
          post[:check] = {}
          post[:check][:account_number] = payment.account_number
          post[:check][:routing_number] = payment.routing_number
        else
          post[:credit_card] = {}
          post[:credit_card][:number] = payment.number
          post[:credit_card][:expiration_month] = payment.month
          post[:credit_card][:expiration_year] = payment.year
          post[:csc] = payment.verification_value
        end
      end

      def add_level_3_data(post, options)
        post[:invoice_id] = options[:invoice_id] if options[:invoice_id]
        post[:customer_reference_id] = options[:customer_reference_id] if options[:customer_reference_id]
        post[:tax_amount] = options[:tax_amount].to_i if options[:tax_amount]
        post[:national_tax_amount] = options[:national_tax_amount].to_i if options[:national_tax_amount]
        post[:merchant_tax_id] = options[:merchant_tax_id] if options[:merchant_tax_id]
        post[:customer_tax_id] = options[:customer_tax_id] if options[:customer_tax_id]
        post[:commodity_code] = options[:commodity_code] if options[:commodity_code]
        post[:discount_amount] = options[:discount_amount].to_i if options[:discount_amount]
        post[:freight_amount] = options[:freight_amount].to_i if options[:freight_amount]
        post[:duty_amount] = options[:duty_amount].to_i if options[:duty_amount]
        post[:additional_tax_amount] = options[:additional_tax_amount].to_i if options[:additional_tax_amount]
        post[:additional_tax_rate] = options[:additional_tax_rate].to_i if options[:additional_tax_rate]

        add_source_address(post, options)
        add_shipping_address(post, options)
        add_line_items(post, options)
      end

      def add_source_address(post, options)
        return unless source_address =  options[:source_address] ||
                                        options[:billing_address] ||
                                        options[:address]

        post[:source_address] = {}
        post[:source_address][:zip] = source_address[:zip] if source_address[:zip]
      end

      def add_shipping_address(post, options)
        return unless shipping_address = options[:shipping_address]

        post[:shipping_address] = {}
        post[:shipping_address][:name] = shipping_address[:name] if shipping_address[:name]
        post[:shipping_address][:street_address] = shipping_address[:address1] if shipping_address[:address1]
        post[:shipping_address][:street_address2] = shipping_address[:address2] if shipping_address[:address2]
        post[:shipping_address][:city] = shipping_address[:city] if shipping_address[:city]
        post[:shipping_address][:state] = shipping_address[:state] if shipping_address[:state]
        post[:shipping_address][:zip] = shipping_address[:zip] if shipping_address[:zip]
        post[:shipping_address][:country] = shipping_address[:country] if shipping_address[:country]
      end

      def add_line_items(post, options)
        return unless options[:line_items]

        line_items = []
        options[:line_items].each do |li|
          obj = {}

          obj[:additional_tax_amount] = li[:additional_tax_amount].to_i if li[:additional_tax_amount]
          obj[:additional_tax_included] = string_literal_to_boolean(li[:additional_tax_included]) if li[:additional_tax_included]
          obj[:additional_tax_rate] = li[:additional_tax_rate].to_i if li[:additional_tax_rate]
          obj[:amount] = li[:amount].to_i if li[:amount]
          obj[:commodity_code] = li[:commodity_code] if li[:commodity_code]
          obj[:debit_or_credit] = li[:debit_or_credit] if li[:debit_or_credit]
          obj[:description] = li[:description] if li[:description]
          obj[:discount_amount] = li[:discount_amount].to_i if li[:discount_amount]
          obj[:discount_rate] = li[:discount_rate].to_i if li[:discount_rate]
          obj[:discount_included] = string_literal_to_boolean(li[:discount_included]) if li[:discount_included]
          obj[:merchant_tax_id] = li[:merchant_tax_id] if li[:merchant_tax_id]
          obj[:product_id] = li[:product_id] if li[:product_id]
          obj[:quantity] = li[:quantity] if li[:quantity]
          obj[:transaction_id] = li[:transaction_id] if li[:transaction_id]
          obj[:tax_included] = string_literal_to_boolean(li[:tax_included]) if li[:tax_included]
          obj[:unit_of_measure] = li[:unit_of_measure] if li[:unit_of_measure]
          obj[:unit_cost] = li[:unit_cost].to_i if li[:unit_cost]

          line_items << obj
        end
        post[:line_items] = line_items
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
        handle_final_response(action, response)
      rescue JSON::ParserError
        unparsable_response(raw_response)
      end

      def handle_final_response(action, response)
        success = success_from(response)

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response['avs_response']),
          cvv_result: response['csc_response'],
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )
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

      def message_from(success, response)
        return response['status_message'] if success

        if error = response['errors']
          message = 'Errors-'
          error.each do |k, v|
            message.concat(" code:#{k}, message:#{v}")
          end
        else
          message = response['status_message'].to_s + " #{response['approval_message']}"
        end

        message
      end

      # store transactions do not return a transaction_id, but they return a customer_id that will then be used as the third_party_token for the stored payment method
      def authorization_from(action, response)
        if action == ENDPOINTS[:store]
          response['customer_id']
        else
          response['transaction_id'] || response['check_transaction_id']
        end
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
