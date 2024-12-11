module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class EbanxGateway < Gateway
      self.test_url = 'https://sandbox.ebanxpay.com/ws/'
      self.live_url = 'https://api.ebanxpay.com/ws/'

      self.supported_countries = %w(BR MX CO CL AR PE BO EC)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club elo hipercard]

      self.homepage_url = 'http://www.ebanx.com/'
      self.display_name = 'EBANX'

      TAGS = ['Spreedly']

      URL_MAP = {
        purchase: 'direct',
        authorize: 'direct',
        capture: 'capture',
        refund: 'refund',
        void: 'cancel',
        store: 'token',
        inquire: 'query',
        verify: 'verifycard'
      }

      HTTP_METHOD = {
        purchase: :post,
        authorize: :post,
        capture: :get,
        refund: :post,
        void: :get,
        store: :post,
        inquire: :get,
        verify: :post
      }

      def initialize(options = {})
        requires!(options, :integration_key)
        super
      end

      def purchase(money, payment, options = {})
        post = { payment: {} }
        add_integration_key(post)
        add_operation(post)
        add_invoice(post, money, options)
        add_customer_data(post, payment, options)
        add_card_or_token(post, payment, options)
        add_address(post, options)
        add_customer_responsible_person(post, payment, options)
        add_additional_data(post, options)
        add_stored_credentials(post, options)

        commit(:purchase, post, options)
      end

      def authorize(money, payment, options = {})
        post = { payment: {} }
        add_integration_key(post)
        add_operation(post)
        add_invoice(post, money, options)
        add_customer_data(post, payment, options)
        add_card_or_token(post, payment, options)
        add_address(post, options)
        add_customer_responsible_person(post, payment, options)
        add_additional_data(post, options)
        add_stored_credentials(post, options)
        post[:payment][:creditcard][:auto_capture] = false

        commit(:authorize, post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_integration_key(post)
        post[:hash] = authorization
        post[:amount] = amount(money) if options[:include_capture_amount].to_s == 'true'

        commit(:capture, post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_integration_key(post)
        add_operation(post)
        add_authorization(post, authorization)
        post[:amount] = amount(money)
        post[:description] = options[:description]

        commit(:refund, post, options)
      end

      def void(authorization, options = {})
        post = {}
        add_integration_key(post)
        add_authorization(post, authorization)

        commit(:void, post, options)
      end

      def store(credit_card, options = {})
        post = {}
        add_integration_key(post)
        customer_country(post, options)
        add_payment_type(post)
        post[:creditcard] = payment_details(credit_card)

        commit(:store, post, options)
      end

      def verify(credit_card, options = {})
        post = {}
        add_integration_key(post)
        add_payment_type(post)
        customer_country(post, options)
        post[:card] = payment_details(credit_card)
        post[:device_id] = options[:device_id] if options[:device_id]

        commit(:verify, post, options)
      end

      def inquire(authorization, options = {})
        post = {}
        add_integration_key(post)
        add_authorization(post, authorization)

        commit(:inquire, post, options)
      end

      def supports_network_tokenization?
        true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(integration_key\\?":\\?")(\w*)/, '\1[FILTERED]').
          gsub(/(card_number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(card_cvv\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(network_token_pan\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(network_token_cryptogram\\?":\\?")([\w+=\/]*)/, '\1[FILTERED]')
      end

      private

      def add_integration_key(post)
        post[:integration_key] = @options[:integration_key].to_s
      end

      def add_operation(post)
        post[:operation] = 'request'
      end

      def add_authorization(post, authorization)
        post[:hash] = authorization
      end

      def add_customer_data(post, payment, options)
        post[:payment][:name] = customer_name(payment, options)
        post[:payment][:email] = options[:email]
        post[:payment][:document] = options[:document]
        post[:payment][:birth_date] = options[:birth_date] if options[:birth_date]
      end

      def add_customer_responsible_person(post, payment, options)
        post[:payment][:person_type] = options[:person_type] if options[:person_type]
        if options[:person_type]&.casecmp('business')&.zero?
          post[:payment][:responsible] = {}
          post[:payment][:responsible][:name] = options[:responsible_name] if options[:responsible_name]
          post[:payment][:responsible][:document] = options[:responsible_document] if options[:responsible_document]
          post[:payment][:responsible][:birth_date] = options[:responsible_birth_date] if options[:responsible_birth_date]
        end
      end

      def add_stored_credentials(post, options)
        return unless (stored_creds = options[:stored_credential])

        post[:cof_info] = {
          cof_type: stored_creds[:initial_transaction] ? 'initial' : 'stored',
          initiator: stored_creds[:initiator] == 'cardholder' ? 'CIT' : 'MIT',
          trans_type: add_trans_type(stored_creds),
          mandate_id: stored_creds[:network_transaction_id]
        }.compact
      end

      def add_trans_type(options)
        case options[:reason_type]
        when 'recurring'
          'SCHEDULED_RECURRING'
        when 'installment'
          'INSTALLMENT'
        else
          options[:initiator] == 'cardholder' ? 'CUSTOMER_COF' : 'MERCHANT_COF'
        end
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:payment][:address] = address[:address1].split[1..-1].join(' ') if address[:address1]
          post[:payment][:street_number] = address[:address1].split.first if address[:address1]
          post[:payment][:city] = address[:city]
          post[:payment][:state] = address[:state]
          post[:payment][:zipcode] = address[:zip]
          post[:payment][:country] = address[:country].downcase
          post[:payment][:phone_number] = address[:phone]
        end
      end

      def add_invoice(post, money, options)
        post[:payment][:amount_total] = amount(money)
        post[:payment][:currency_code] = (options[:currency] || currency(money))
        post[:payment][:merchant_payment_code] = Digest::MD5.hexdigest(options[:order_id])
        post[:payment][:instalments] = options[:instalments] || 1
        post[:payment][:order_number] = options[:order_id][0..39] if options[:order_id]
      end

      def add_card_or_token(post, payment, options)
        payment = payment.split('|')[0] if payment.is_a?(String)
        add_payment_type(post[:payment])
        post[:payment][:creditcard] = payment_details(payment)
        post[:payment][:creditcard][:soft_descriptor] = options[:soft_descriptor] if options[:soft_descriptor]
      end

      def add_payment_type(post)
        post[:payment_type_code] = 'creditcard'
      end

      def payment_details(payment)
        case payment
        when NetworkTokenizationCreditCard
          {
            network_token_pan: payment.number,
            network_token_expire_date: "#{payment.month}/#{payment.year}",
            network_token_cryptogram: payment.payment_cryptogram
          }
        when String
          { token: payment }
        else
          {
            card_number: payment.number,
            card_name: payment.name,
            card_due_date: "#{payment.month}/#{payment.year}",
            card_cvv: payment.verification_value
          }
        end
      end

      def add_additional_data(post, options)
        post[:device_id] = options[:device_id] if options[:device_id]
        post[:metadata] = options[:metadata] if options[:metadata]
        post[:metadata] = {} if post[:metadata].nil?
        post[:metadata][:merchant_payment_code] = options[:order_id] if options[:order_id]
        post[:payment][:tags] = TAGS
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, options = {})
        url = url_for((test? ? test_url : live_url), action, parameters)

        response = parse(ssl_request(HTTP_METHOD[action], url, post_data(action, parameters), headers(options)))

        success = success_from(action, response)

        Response.new(
          success,
          message_from(action, response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: error_code_from(response, success)
        )
      end

      def headers(options)
        {
          'x-ebanx-client-user-agent' => "ActiveMerchant/#{ActiveMerchant::VERSION}",
          'x-ebanx-api-processing-type' => ('local' if options[:processing_type] == 'local')
        }.compact
      end

      def success_from(action, response)
        status = response.dig('payment', 'status')

        case action
        when :purchase, :capture, :refund
          status == 'CO'
        when :authorize
          status == 'PE'
        when :void
          status == 'CA'
        when :verify
          response.dig('card_verification', 'transaction_status', 'code') == 'OK'
        when :store, :inquire
          response.dig('status') == 'SUCCESS'
        else
          false
        end
      end

      def message_from(action, response)
        return response['status_message'] if response['status'] == 'ERROR'

        if action == :verify
          response.dig('card_verification', 'transaction_status', 'description')
        else
          response.dig('payment', 'transaction_status', 'description')
        end
      end

      def authorization_from(action, parameters, response)
        if action == :store
          if success_from(action, response)
            "#{response.try(:[], 'token')}|#{response['payment_type_code']}"
          else
            response.try(:[], 'token')
          end
        else
          response.try(:[], 'payment').try(:[], 'hash')
        end
      end

      def post_data(action, parameters = {})
        return nil if requires_http_get(action)
        return convert_to_url_form_encoded(parameters) if action == :refund

        "request_body=#{parameters.to_json}"
      end

      def url_for(hostname, action, parameters)
        return "#{hostname}#{URL_MAP[action]}?#{convert_to_url_form_encoded(parameters)}" if requires_http_get(action)

        "#{hostname}#{URL_MAP[action]}"
      end

      def requires_http_get(action)
        return true if %i[capture void inquire].include?(action)

        false
      end

      def convert_to_url_form_encoded(parameters)
        parameters.map do |key, value|
          next if value != false && value.blank?

          "#{key}=#{value}"
        end.compact.join('&')
      end

      def error_code_from(response, success)
        unless success
          return response['status_code'] if response['status'] == 'ERROR'

          response.try(:[], 'payment').try(:[], 'transaction_status').try(:[], 'code')
        end
      end

      def customer_country(post, options)
        if country = options[:country] || (options[:billing_address][:country] if options[:billing_address])
          post[:country] = country.downcase
        end
      end

      def customer_name(payment, options)
        address_name = options[:billing_address][:name] if options[:billing_address] && options[:billing_address][:name]
        if payment.is_a?(String)
          address_name || 'Not Provided'
        else
          payment.name
        end
      end
    end
  end
end
