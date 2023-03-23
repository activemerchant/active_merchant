module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EbanxV1Gateway

      URL_MAP = {
        purchase: 'direct',
        authorize: 'direct',
        capture: 'capture',
        refund: 'refund',
        void: 'cancel',
        store: 'token',
        inquire: 'query'
      }

      HTTP_METHOD = {
        purchase: :post,
        authorize: :post,
        capture: :get,
        refund: :post,
        void: :get,
        store: :post,
        inquire: :get
      }

      TAGS = ['Spreedly']

      def initialize(integration_key)
        @integration_key = integration_key
        @test_url = 'https://sandbox.ebanxpay.com/ws/'
        @live_url = 'https://api.ebanxpay.com/ws/'
      end

      def purchase(amount, currency, payment, options = {})
        post = { payment: {} }
        add_integration_key(post)
        add_operation(post)
        add_invoice(post, amount, currency, options)
        add_customer_data(post, payment, options)
        add_card_or_token(post, payment, options)
        add_address(post, options)
        add_customer_responsible_person(post, payment, options)
        add_additional_data(post, options)

        post
      end

      def authorize(amount, currency, payment, options = {})
        post = { payment: {} }

        add_integration_key(post)
        add_operation(post)
        add_invoice(post, amount, currency, options)
        add_customer_data(post, payment, options)
        add_card_or_token(post, payment, options)
        add_address(post, options)
        add_customer_responsible_person(post, payment, options)
        add_additional_data(post, options)
        post[:payment][:creditcard][:auto_capture] = false

        post
      end

      def capture(money, authorization, options = {})
        post = {}
        add_integration_key(post)
        post[:hash] = authorization
        post[:amount] = money if options[:include_capture_amount].to_s == 'true'

        post
      end

      def refund(money, authorization, options = {})
        post = {}
        add_integration_key(post)
        add_operation(post)
        add_authorization(post, authorization)
        post[:amount] = money
        post[:description] = options[:description]

        post
      end

      def void(authorization, options = {})
        post = {}
        add_integration_key(post)
        add_authorization(post, authorization)

        post
      end

      def store(credit_card, options = {})
        post = {}
        add_integration_key(post)
        add_payment_details(post, credit_card)
        post[:country] = customer_country(options)

        post
      end

      def inquire(authorization, options = {})
        post = {}
        add_integration_key(post)
        add_authorization(post, authorization)

        post
      end

      def url_for(is_test_env, action, parameters)
        hostname = is_test_env ? @test_url : @live_url
        return "#{hostname}#{URL_MAP[action]}?#{convert_to_url_form_encoded(parameters)}" if requires_http_get(action)

        "#{hostname}#{URL_MAP[action]}"
      end

      def get_http_method(action)
        HTTP_METHOD[action]
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

      def headers(params)
        processing_type = params[:processing_type]
        commit_headers = { 'x-ebanx-client-user-agent': "ActiveMerchant/#{ActiveMerchant::VERSION}" }

        add_processing_type_to_commit_headers(commit_headers, processing_type) if processing_type == 'local'

        commit_headers
      end

      def customer_country(options)
        if country = options[:country] || (options[:billing_address][:country] if options[:billing_address])
          country.downcase
        end
      end

      private

      def add_integration_key(post)
        post[:integration_key] = @integration_key
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

      def add_invoice(post, amount, currency, options)
        post[:payment][:amount_total] = amount
        post[:payment][:currency_code] = currency
        post[:payment][:merchant_payment_code] = Digest::MD5.hexdigest(options[:order_id])
        post[:payment][:instalments] = options[:instalments] || 1
        post[:payment][:order_number] = options[:order_id][0..39] if options[:order_id]
      end

      def add_card_or_token(post, payment, options)
        payment = payment.split('|')[0] if payment.is_a?(String)
        post[:payment][:payment_type_code] = 'creditcard'
        post[:payment][:creditcard] = payment_details(payment)
        post[:payment][:creditcard][:soft_descriptor] = options[:soft_descriptor] if options[:soft_descriptor]
      end

      def add_payment_details(post, payment)
        post[:payment_type_code] = 'creditcard'
        post[:creditcard] = payment_details(payment)
      end

      def payment_details(payment)
        if payment.is_a?(String)
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
        post[:processing_type] = options[:processing_type] if options[:processing_type]
        post[:payment][:tags] = TAGS
      end

      def customer_name(payment, options)
        address_name = options[:billing_address][:name] if options[:billing_address] && options[:billing_address][:name]
        if payment.is_a?(String)
          address_name || 'Not Provided'
        else
          payment.name
        end
      end

      def requires_http_get(action)
        return true if %i[capture void inquire].include?(action)

        false
      end

      def add_processing_type_to_commit_headers(commit_headers, processing_type)
        commit_headers['x-ebanx-api-processing-type'] = processing_type
      end

      def convert_to_url_form_encoded(parameters)
        parameters.map do |key, value|
          next if value != false && value.blank?

          "#{key}=#{value}"
        end.compact.join('&')
      end
    end
  end
end