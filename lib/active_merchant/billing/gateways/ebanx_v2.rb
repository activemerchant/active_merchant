module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EbanxV2Gateway < Gateway
      self.test_url = 'https://sandbox.ebanxpay.com/channels/spreedly'
      self.live_url = 'http://api.ebanxpay.com/channels/spreedly/'

      self.supported_countries = %w(BR MX CO CL AR PE)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club]

      self.homepage_url = 'http://www.ebanx.com/'
      self.display_name = 'EBANX'

      TAGS = ['Spreedly']

      CARD_BRAND = {
        visa: 'visa',
        master: 'master_card',
        american_express: 'amex',
        discover: 'discover',
        diners_club: 'diners'
      }

      URL_MAP = {
        purchase: 'purchase',
        authorize: 'direct',
        capture: 'capture',
        refund: 'refund',
        void: 'cancel',
        store: 'token'
      }

      HTTP_METHOD = {
        purchase: :post,
        authorize: :post,
        capture: :post,
        refund: :post,
        void: :post,
        store: :post
      }

      VERIFY_AMOUNT_PER_COUNTRY = {
        'br' => 100,
        'ar' => 100,
        'co' => 50000,
        'pe' => 300,
        'mx' => 2000,
        'cl' => 80000
      }

      def initialize(options = {})
        requires!(options, :integration_key)
        super
      end

      def purchase(money, payment, options = {})
        payload = {}

        add_amount(payload, money)
        add_options(payload, options)
        add_gateway_specific_fields(payload, options)
        add_card_or_token(payload, payment)

        commit(:purchase, payload, headers(options))
      end

      def authorize(money, payment, options = {})
        payload = {}

        add_amount(payload, money)
        add_options(payload, options)
        add_gateway_specific_fields(payload, options)
        add_card_or_token(payload, payment)

        payload[:creditcard][:auto_capture] = false

        commit(:authorize, payload, headers(options))
      end

      def capture(money, authorization, options = {})
        payload = {}
        payload[:authorization] = authorization
        payload[:amount] = add_amount(payload, money) if options[:include_capture_amount].to_s == 'true'

        commit(:capture, payload, headers(options))
      end

      def refund(money, authorization, options = {})
        payload = {}

        payload[:authorization] = authorization
        payload[:amount] = add_amount(payload, money)
        payload[:description] = options[:description]

        commit(:refund, payload, headers(options))
      end

      def void(authorization, options = {})
        payload = {}
        payload[:authorization] = authorization

        commit(:void, payload, headers(options))
      end

      def store(credit_card, options = {})
        post = {}
        add_payment_details(post, credit_card)
        post[:country] = customer_country(options)

        commit(:store, post, headers(options))
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(VERIFY_AMOUNT_PER_COUNTRY[customer_country(options)], credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def add_amount(payload, amount)
        payload[:amount] = amount(amount)
      end

      def add_options(payload, options)
        payload[:options] = {}

        payload[:options][:order_id] = options[:order_id]
        payload[:options][:ip] = options[:ip]
        payload[:options][:customer] = options[:customer]
        payload[:options][:invoice] = options[:invoice]
        payload[:options][:merchant] = options[:merchant]
        payload[:options][:description] = options[:description]
        payload[:options][:email] = options[:email]
        payload[:options][:currency] = options[:currency]
        add_billing_address(payload, options[:billing_address])
      end

      def add_billing_address(payload, billing_address)
        payload[:billing_address] = {}

        payload[:billing_address][:name] = billing_address[:name]
        payload[:billing_address][:address1] = billing_address[:address1]
        payload[:billing_address][:address2] = billing_address[:address2]
        payload[:billing_address][:company] = billing_address[:company]
        payload[:billing_address][:city] = billing_address[:city]
        payload[:billing_address][:state] = billing_address[:state]
        payload[:billing_address][:zip] = billing_address[:zip]
        payload[:billing_address][:country] = billing_address[:country]
        payload[:billing_address][:phone] = billing_address[:phone]
        payload[:billing_address][:fax] = billing_address[:fax]
      end

      def add_gateway_specific_fields(payload, options)
        payload[:gateway_specific_fields] = {}

        payload[:gateway_specific_fields][:document] = options[:document]
        payload[:gateway_specific_fields][:description] = options[:description]
        payload[:gateway_specific_fields][:birth_date] = options[:birth_date]
        payload[:gateway_specific_fields][:instalments] = options[:instalments]
        payload[:gateway_specific_fields][:country] = options[:country]
        payload[:gateway_specific_fields][:person_type] = options[:person_type]
        payload[:gateway_specific_fields][:responsible_name] = options[:responsible_name]
        payload[:gateway_specific_fields][:responsible_document] = options[:responsible_document]
        payload[:gateway_specific_fields][:responsible_birth_date] = options[:responsible_birth_date]
        payload[:gateway_specific_fields][:include_capture_amount] = options[:include_capture_amount]
        payload[:gateway_specific_fields][:device_id] = options[:device_id]
        payload[:gateway_specific_fields][:metadata] = options[:metadata]
        payload[:gateway_specific_fields][:processing_type] = options[:processing_type]
        payload[:gateway_specific_fields][:soft_descriptor] = options[:soft_descriptor]
      end

      def headers(options)
        headers = { 'x-ebanx-client-user-agent': "ActiveMerchant/#{ActiveMerchant::VERSION}" }
        headers['authorization'] = @options[:integration_key]

        processing_type = options[:processing_type]
        add_processing_type_to_headers(headers, processing_type) if processing_type == 'local'

        headers
      end

      def add_processing_type_to_headers(commit_headers, processing_type)
        commit_headers['x-ebanx-api-processing-type'] = processing_type
      end

      def customer_country(options)
        if country = options[:country] || (options[:billing_address][:country] if options[:billing_address])
          country.downcase
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(integration_key\\?":\\?")(\w*)/, '\1[FILTERED]').
          gsub(/(card_number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(card_cvv\\?":\\?")(\d*)/, '\1[FILTERED]')
      end

      def add_card_or_token(post, payment)
        post[:creditcard] = {}

        payment, brand = payment.split('|') if payment.is_a?(String)
        post[:creditcard] = payment_details(payment)
        post[:creditcard][:brand] = payment.is_a?(String) ? brand : payment.brand.to_sym
      end

      def add_payment_details(post, payment)
        post[:creditcard] = payment_details(payment)
        post[:creditcard][:brand] = payment.brand.to_sym
      end

      def payment_details(payment)
        if payment.is_a?(String)
          { token: payment }
        else
          {
            number: payment.number,
            first_name: payment.first_name,
            last_name: payment.last_name,
            month: payment.month,
            year: payment.year,
            verification_value: payment.verification_value
          }
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, headers)
        print post_data(parameters)
        url = url_for((test? ? test_url : live_url), action, parameters)
        response = parse(ssl_request(HTTP_METHOD[action], url, post_data(parameters), headers))
        success = success_from(action, response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: error_code_from(response, success)
        )
      end

      def success_from(action, response)
        if %i[purchase capture refund].include?(action)
          response.try(:[], 'payment').try(:[], 'status') == 'CO'
        elsif action == :authorize
          response.try(:[], 'payment').try(:[], 'status') == 'PE'
        elsif action == :void
          response.try(:[], 'payment').try(:[], 'status') == 'CA'
        elsif action == :store
          response.try(:[], 'status') == 'SUCCESS'
        else
          false
        end
      end

      def message_from(response)
        return response['status_message'] if response['status'] == 'ERROR'

        response.try(:[], 'payment').try(:[], 'transaction_status').try(:[], 'description')
      end

      def authorization_from(action, parameters, response)
        if action == :store
          "#{response.try(:[], 'token')}|#{CARD_BRAND[parameters[:creditcard][:brand].to_sym]}"
        else
          response.try(:[], 'payment').try(:[], 'hash')
        end
      end

      def post_data(parameters = {})
        "request_body=#{parameters.to_json}"
      end

      def url_for(hostname, action, parameters)
        "#{hostname}#{URL_MAP[action]}"
      end

      def error_code_from(response, success)
        unless success
          return response['status_code'] if response['status'] == 'ERROR'

          response.try(:[], 'payment').try(:[], 'transaction_status').try(:[], 'code')
        end
      end
    end
  end
end
