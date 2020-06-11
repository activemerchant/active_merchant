module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MundipaggGateway < Gateway
      self.live_url = 'https://api.mundipagg.com/core/v1'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover alelo]

      self.homepage_url = 'https://www.mundipagg.com/'
      self.display_name = 'Mundipagg'

      STANDARD_ERROR_CODE_MAPPING = {
        '400' => STANDARD_ERROR_CODE[:processing_error],
        '401' => STANDARD_ERROR_CODE[:config_error],
        '404' => STANDARD_ERROR_CODE[:processing_error],
        '412' => STANDARD_ERROR_CODE[:processing_error],
        '422' => STANDARD_ERROR_CODE[:processing_error],
        '500' => STANDARD_ERROR_CODE[:processing_error]
      }

      STANDARD_ERROR_MESSAGE_MAPPING = {
        '400' => 'Invalid request;',
        '401' => 'Invalid API key;',
        '404' => 'The requested resource does not exist;',
        '412' => 'Valid parameters but request failed;',
        '422' => 'Invalid parameters;',
        '500' => 'An internal error occurred;'
      }

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options) unless payment.is_a?(String)
        add_shipping_address(post, options)
        add_payment(post, payment, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options) unless payment.is_a?(String)
        add_shipping_address(post, options)
        add_payment(post, payment, options)
        add_capture_flag(post, payment)
        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:code] = authorization
        add_invoice(post, money, options)
        commit('capture', post, authorization)
      end

      def refund(money, authorization, options={})
        add_invoice(post = {}, money, options)
        commit('refund', post, authorization)
      end

      def void(authorization, options={})
        commit('void', nil, authorization)
      end

      def store(payment, options={})
        post = {}
        options.update(name: payment.name)
        options = add_customer(options) unless options[:customer_id]
        add_payment(post, payment, options)
        commit('store', post, options[:customer_id])
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("cvv\\":\\")\d*), '\1[FILTERED]').
          gsub(%r((card\\":{\\"number\\":\\")\d*), '\1[FILTERED]')
      end

      private

      def add_customer(options)
        post = {}
        post[:name] = options[:name]
        customer = commit('customer', post)
        options.update(customer_id: customer.authorization)
      end

      def add_customer_data(post, options)
        post[:customer] = {}
        post[:customer][:email] = options[:email]
      end

      def add_billing_address(post, type, options)
        if address = (options[:billing_address] || options[:address])
          billing = {}
          address = options[:billing_address] || options[:address]
          billing[:street] = address[:address1].match(/\D+/)[0].strip if address[:address1]
          billing[:number] = address[:address1].match(/\d+/)[0] if address[:address1]
          billing[:compliment] = address[:address2] if address[:address2]
          billing[:city] = address[:city] if address[:city]
          billing[:state] = address[:state] if address[:state]
          billing[:country] = address[:country] if address[:country]
          billing[:zip_code] = address[:zip] if address[:zip]
          billing[:neighborhood] = address[:neighborhood]
          post[:payment][type.to_sym][:card][:billing_address] = billing
        end
      end

      def add_shipping_address(post, options)
        if address = options[:shipping_address]
          post[:address] = {}
          post[:address][:street] = address[:address1].match(/\D+/)[0].strip if address[:address1]&.match(/\D+/)
          post[:address][:number] = address[:address1].match(/\d+/)[0] if address[:address1]&.match(/\d+/)
          post[:address][:compliment] = address[:address2] if address[:address2]
          post[:address][:city] = address[:city] if address[:city]
          post[:address][:state] = address[:state] if address[:state]
          post[:address][:country] = address[:country] if address[:country]
          post[:address][:zip_code] = address[:zip] if address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = money
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_capture_flag(post, payment)
        if voucher?(payment)
          post[:payment][:voucher][:capture] = false
        else
          post[:payment][:credit_card][:capture] = false
        end
      end

      def add_payment(post, payment, options)
        post[:customer][:name] = payment.name if post[:customer]
        post[:customer_id] = parse_auth(payment)[0] if payment.is_a?(String)
        post[:payment] = {}
        affiliation = options[:gateway_affiliation_id] || @options[:gateway_id]
        post[:payment][:gateway_affiliation_id] = affiliation if affiliation
        post[:payment][:metadata] = { mundipagg_payment_method_code: '1' } if test?
        if voucher?(payment)
          add_voucher(post, payment, options)
        else
          add_credit_card(post, payment, options)
        end
      end

      def add_credit_card(post, payment, options)
        post[:payment][:payment_method] = 'credit_card'
        post[:payment][:credit_card] = {}
        if payment.is_a?(String)
          post[:payment][:credit_card][:card_id] = parse_auth(payment)[1]
        else
          post[:payment][:credit_card][:card] = {}
          post[:payment][:credit_card][:card][:number] = payment.number
          post[:payment][:credit_card][:card][:holder_name] = payment.name
          post[:payment][:credit_card][:card][:exp_month] = payment.month
          post[:payment][:credit_card][:card][:exp_year] = payment.year
          post[:payment][:credit_card][:card][:cvv] = payment.verification_value
          post[:payment][:credit_card][:card][:holder_document] = options[:holder_document] if options[:holder_document]
          add_billing_address(post, 'credit_card', options)
        end
      end

      def add_voucher(post, payment, options)
        post[:currency] = 'BRL'
        post[:payment][:payment_method] = 'voucher'
        post[:payment][:voucher] = {}
        post[:payment][:voucher][:card] = {}
        post[:payment][:voucher][:card][:number] = payment.number
        post[:payment][:voucher][:card][:holder_name] = payment.name
        post[:payment][:voucher][:card][:holder_document] = options[:holder_document]
        post[:payment][:voucher][:card][:exp_month] = payment.month
        post[:payment][:voucher][:card][:exp_year] = payment.year
        post[:payment][:voucher][:card][:cvv] = payment.verification_value
        add_billing_address(post, 'voucher', options)
      end

      def voucher?(payment)
        return false if payment.is_a?(String)

        %w[sodexo vr].include? card_brand(payment)
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:api_key]}:"),
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def url_for(action, auth = nil)
        url = live_url
        case action
        when 'store'
          "#{url}/customers/#{auth}/cards/"
        when 'customer'
          "#{url}/customers/"
        when 'refund', 'void'
          "#{url}/charges/#{auth}/"
        when 'capture'
          "#{url}/charges/#{auth}/capture/"
        else
          "#{url}/charges/"
        end
      end

      def commit(action, parameters, auth = nil)
        url = url_for(action, auth)
        parameters.merge!(parameters[:payment][:credit_card].delete(:card)).delete(:payment) if action == 'store'
        response = if %w[refund void].include? action
                     parse(ssl_request(:delete, url, post_data(parameters), headers))
                   else
                     parse(ssl_post(url, post_data(parameters), headers))
                   end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, action),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        message = get_error_messages(e)

        return Response.new(
          false,
          "#{STANDARD_ERROR_MESSAGE_MAPPING[e.response.code]} #{message}",
          parse(e.response.body),
          test: test?,
          error_code: STANDARD_ERROR_CODE_MAPPING[e.response.code]
        )
      end

      def success_from(response)
        %w[pending paid processing canceled active].include? response['status']
      end

      def message_from(response)
        return gateway_response_errors(response) if gateway_response_errors?(response)
        return response['message'] if response['message']
        return response['last_transaction']['acquirer_message'] if response['last_transaction']
      end

      def get_error_messages(error)
        parsed_response_body = parse(error.response.body)
        message = parsed_response_body['message']

        parsed_response_body['errors']&.each do |type, descriptions|
          message += ' | '
          message += descriptions.join(', ')
        end

        message
      end

      def gateway_response_errors?(response)
        response.try(:[], 'last_transaction').try(:[], 'gateway_response').try(:[], 'errors').present?
      end

      def gateway_response_errors(response)
        error_string = ''

        response['last_transaction']['gateway_response']['errors']&.each do |error|
          error.each do |key, value|
            error_string += ' | ' unless error_string.blank?
            error_string += value
          end
        end

        error_string
      end

      def authorization_from(response, action)
        return "#{response['customer']['id']}|#{response['id']}" if action == 'store'

        response['id']
      end

      def parse_auth(auth)
        auth.split('|')
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        return if success_from(response)
        return response['last_transaction']['acquirer_return_code'] if response['last_transaction']

        STANDARD_ERROR_CODE[:processing_error]
      end
    end
  end
end
