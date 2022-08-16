require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ForteGateway < Gateway
      include Empty

      self.test_url = 'https://sandbox.forte.net/api/v3/'
      self.live_url = 'https://api.forte.net/v3/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.forte.net'
      self.display_name = 'Forte'

      def initialize(options = {})
        requires!(options, :api_key, :secret, :location_id)
        unless options.key?(:organization_id) || options.key?(:account_id)
          raise ArgumentError.new('Missing required parameter: organization_id or account_id')
        end

        super
      end

      def purchase(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method, options)
        add_billing_address(post, payment_method, options) unless payment_method.is_a?(String)
        add_shipping_address(post, options) unless payment_method.is_a?(String)
        post[:action] = 'sale'

        commit(:post, 'transactions', post)
      end

      def authorize(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method, options)
        add_billing_address(post, payment_method, options)
        add_shipping_address(post, options)
        post[:action] = 'authorize'

        commit(:post, 'transactions', post)
      end

      def capture(_money, authorization, _options = {})
        post = {}
        post[:transaction_id] = transaction_id_from(authorization)
        post[:authorization_code] = authorization_code_from(authorization) || ''
        post[:action] = 'capture'

        commit(:put, 'transactions', post)
      end

      def credit(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method, options)
        add_billing_address(post, payment_method, options)
        post[:action] = 'credit'

        commit(:post, 'transactions', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)
        post[:original_transaction_id] = transaction_id_from(authorization)
        post[:authorization_code] = authorization_code_from(authorization)
        post[:action] = 'reverse'

        commit(:post, 'transactions', post)
      end

      def store(payment_method, options = {})
        customer_token = options.delete(:customer_token)

        if customer_token.present?
          create_paymethod_and_address_for_customer(customer_token, payment_method, options)
        else
          create_customer_and_payment_method(payment_method, options)
        end
      end

      def unstore(identification, _options = {})
        customer_token, paymethod_token = identification.split('|')

        if customer_token && !paymethod_token
          commit(:delete, "customers/#{customer_token}", {})
        else
          commit(:delete, "paymethods/#{paymethod_token}", {})
        end
      end

      def update(payment_method, options = {})
        MultiResponse.run do |r|
          customer_token = options.delete(:customer_token)
          paymethod_token = options.delete(:paymethod_token)
          get_paymethod_response = nil

          r.process do
            params = {}
            add_customer(params, payment_method, options)

            update_customer(customer_token, params)
          end

          r.process do
            params = {}
            if payment_method.is_a?(Check)
              add_echeck(params, payment_method, options)
            else
              add_credit_card(params, payment_method)
            end

            update_clientless_paymethod(paymethod_token, params)
          end

          r.process { get_paymethod_response = get_paymethod(paymethod_token) }
          billing_address_token = get_paymethod_response.params['billing_address_token']

          if billing_address_token.present?
            address_options = {}
            add_email(address_options, options)
            if options[:billing_address].present?
              add_physical_address(address_options, options)
            end
            r.process { update_address(billing_address_token, address_options) } if address_options.keys.present?
          else
            # TODO: add a new address and attach it to the paymethod
          end

          r.process { get_customer(customer_token) }
        end
      end

      def void(authorization, _options = {})
        post = {}
        post[:transaction_id] = transaction_id_from(authorization)
        post[:authorization_code] = authorization_code_from(authorization)
        post[:action] = 'void'

        commit(:put, 'transactions', post)
      end

      def verify(credit_card, _options = {})
        path = 'transactions'

        params = {}
        add_action(params, 'verify')
        add_credit_card(params, credit_card)
        add_first_and_last_name(params, credit_card)

        commit(:post, path, params)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization: Basic )\w+/, '\1[FILTERED]')
          .gsub(/(account_number)\W+\d+/, '\1[FILTERED]')
          .gsub(/(routing_number)\W+\d+/, '\1[FILTERED]')
          .gsub(/(card_verification_value)\W+\d+/, '\1[FILTERED]')
      end

      private

      def create_paymethod_and_address_for_customer(customer_token, payment_method, options)
        MultiResponse.run do |r|
          create_paymethod_response = nil
          create_address_response = nil

          r.process { create_paymethod_response = create_paymethod_for_customer(customer_token, payment_method, options) }

          if create_paymethod_response&.success?
            new_paymethod_token = create_paymethod_response.params['paymethod_token']

            if options[:billing_address].present?
              r.process { create_address_response = create_address_for_customer(customer_token, options) }

              if create_address_response&.success?
                new_address_token = create_address_response.params['address_token']

                r.process { update_paymethod_address(new_paymethod_token, new_address_token) }
              end
            end

            customer_params = {}
            customer_params[:default_paymethod_token] = new_paymethod_token
            customer_params[:first_name] = options[:customer][:first_name] if options.dig(:customer, :first_name)
            customer_params[:last_name] = options[:customer][:last_name] if options.dig(:customer, :last_name)

            r.process { update_customer(customer_token, customer_params) }
          end
        end
      end

      def create_paymethod_for_customer(customer_token, payment_method, options)
        path = ['customers', customer_token, 'paymethods'].join('/')
        params = {}

        if payment_method.is_a?(Check)
          add_echeck(params, payment_method, options)
        else
          add_credit_card(params, payment_method)
        end

        commit(:post, path, params)
      end

      def create_customer_and_payment_method(payment_method, options)
        path = 'customers'
        params = {}
        add_customer(params, payment_method, options)
        add_customer_paymethod(params, payment_method, options)
        add_customer_billing_address(params, options)

        commit(:post, path, params)
      end

      def create_address_for_customer(customer_token, options)
        path = ['customers', customer_token, 'addresses'].join('/')
        params = {}
        add_physical_address(params, options)

        commit(:post, path, params)
      end

      def get_paymethod(paymethod_token)
        path = ['paymethods', paymethod_token].join('/')

        commit(:get, path)
      end

      def get_customer(customer_token)
        path = ['customers', customer_token].join('/')

        commit(:get, path)
      end

      def update_paymethod_address(paymethod_token, new_address_token)
        path = ['paymethods', paymethod_token].join('/')
        params = { billing_address_token: new_address_token }

        commit(:put, path, params)
      end

      def update_clientless_paymethod(paymethod_token, options)
        path = ['paymethods', paymethod_token].join('/')
        if options[:card].present?
          options[:card].delete(:account_number)
        elsif options[:echeck].present?
          options[:echeck].delete(:account_number)
        end

        commit(:put, path, options)
      end

      def update_customer(customer_token, options)
        path = ['customers', customer_token].join('/')
        allowed_fields = %i[default_shipping_address_token default_billing_address_token default_paymethod_token paymethod_token first_name last_name company_name status]
        params = options.slice(*allowed_fields)

        commit(:put, path, params)
      end

      def update_address(address_token, options)
        path = ['addresses', address_token].join('/')

        commit(:put, path, options)
      end

      def add_invoice(post, options)
        post[:order_number] = options[:order_id]
      end

      def add_amount(post, money, _options)
        post[:authorization_amount] = amount(money)
      end

      def add_customer(post, payment_method, options)
        post[:first_name] = options.dig(:customer, :first_name) || payment_method.first_name
        post[:last_name] = options.dig(:customer, :last_name) || payment_method.last_name
      end

      def add_customer_paymethod(post, payment_method, options)
        post[:paymethod] = {}

        if payment_method.is_a?(Check)
          add_echeck(post[:paymethod], payment_method, options)
        else
          post[:paymethod][:card] = {}
          post[:paymethod][:card][:card_type] = format_card_brand(payment_method.brand)
          post[:paymethod][:card][:name_on_card] = payment_method.name
          post[:paymethod][:card][:account_number] = payment_method.number
          post[:paymethod][:card][:expire_month] = payment_method.month
          post[:paymethod][:card][:expire_year] = payment_method.year
          post[:paymethod][:card][:card_verification_value] = payment_method.verification_value
        end
      end

      def add_customer_billing_address(post, options)
        return unless (address = options[:billing_address] || options[:address])

        post[:addresses] = []
        billing_address = {}
        billing_address[:address_type] = 'default_billing'
        billing_address[:physical_address] = {}
        billing_address[:physical_address][:street_line1] = address[:address1] if address[:address1]
        billing_address[:physical_address][:street_line2] = address[:address2] if address[:address2]
        billing_address[:physical_address][:postal_code] = address[:zip] if address[:zip]
        billing_address[:physical_address][:region] = address[:state] if address[:state]
        billing_address[:physical_address][:locality] = address[:city] if address[:city]
        billing_address[:email] = options[:email] if options[:email]
        post[:addresses] << billing_address
      end

      def add_billing_address(post, payment, options)
        post[:billing_address] = {}
        if (address = options[:billing_address] || options[:address])
          first_name, last_name = split_names(address[:name])
          post[:billing_address][:first_name] = first_name if first_name
          post[:billing_address][:last_name] = last_name if last_name
          post[:billing_address][:physical_address] = {}
          post[:billing_address][:physical_address][:street_line1] = address[:address1] if address[:address1]
          post[:billing_address][:physical_address][:street_line2] = address[:address2] if address[:address2]
          post[:billing_address][:physical_address][:postal_code] = address[:zip] if address[:zip]
          post[:billing_address][:physical_address][:region] = address[:state] if address[:state]
          post[:billing_address][:physical_address][:locality] = address[:city] if address[:city]
        end

        post[:billing_address][:first_name] = payment.first_name if empty?(post[:billing_address][:first_name]) && payment.first_name

        post[:billing_address][:last_name] = payment.last_name if empty?(post[:billing_address][:last_name]) && payment.last_name
      end

      def add_email(params, options)
        params[:email] = options[:email] if options[:email]
      end

      def add_physical_address(params, options)
        address = options[:billing_address]
        return unless address.present?

        params[:physical_address] = {}
        params[:physical_address][:street_line1] = address[:address1] if address[:address1]
        params[:physical_address][:street_line2] = address[:address2] if address[:address2]
        params[:physical_address][:locality] = address[:city] if address[:city]
        params[:physical_address][:region] = address[:state] if address[:state]
        params[:physical_address][:country] = address[:country] if address[:country]
        params[:physical_address][:postal_code] = address[:zip] if address[:zip]
      end

      def add_shipping_address(post, options)
        return unless options[:shipping_address]

        address = options[:shipping_address]

        post[:shipping_address] = {}
        first_name, last_name = split_names(address[:name])
        post[:shipping_address][:first_name] = first_name if first_name
        post[:shipping_address][:last_name] = last_name if last_name
        post[:shipping_address][:physical_address][:street_line1] = address[:address1] if address[:address1]
        post[:shipping_address][:physical_address][:street_line2] = address[:address2] if address[:address2]
        post[:shipping_address][:physical_address][:postal_code] = address[:zip] if address[:zip]
        post[:shipping_address][:physical_address][:region] = address[:state] if address[:state]
        post[:shipping_address][:physical_address][:locality] = address[:city] if address[:city]
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(String)
          add_payment_method_tokens(post, payment_method, options)
        elsif payment_method.respond_to?(:brand)
          add_credit_card(post, payment_method)
        else
          add_echeck(post, payment_method, options)
        end
      end

      def add_echeck(post, payment, options)
        post[:echeck] = {}
        post[:echeck][:account_holder] = payment.name if payment.name
        post[:echeck][:account_number] = payment.account_number if payment.account_number
        post[:echeck][:routing_number] = payment.routing_number if payment.routing_number
        post[:echeck][:account_type] = payment.account_type if payment.account_type
        post[:echeck][:sec_code] = options[:sec_code] || 'PPD'
      end

      def add_echeck_sec_code(post, options)
        if options[:sec_code]
          post[:echeck] ||= {}
          post[:echeck][:sec_code] = options[:sec_code]
        end
      end

      def add_credit_card(params, payment_method)
        params[:card] = {}
        params[:card][:card_type] = format_card_brand(payment_method.brand) if payment_method.brand
        params[:card][:name_on_card] = payment_method.name if payment_method.name
        params[:card][:account_number] = payment_method.number if payment_method.number
        params[:card][:expire_month] = payment_method.month if payment_method.month
        params[:card][:expire_year] = payment_method.year if payment_method.year
        params[:card][:card_verification_value] = payment_method.verification_value if payment_method.verification_value
      end

      def add_first_and_last_name(params, payment_method)
        params[:billing_address] = {
          first_name: payment_method.first_name,
          last_name: payment_method.last_name
        }
      end

      def add_action(params, action_name)
        params[:action] = action_name
      end

      def add_payment_method_tokens(post, payment_method, options)
        if payment_method.include?('|')
          customer_token, paymethod_token = payment_method.split('|')
          add_customer_token(post, customer_token)
          add_paymethod_token(post, paymethod_token)
          add_echeck_sec_code(post, options)
        else
          add_customer_token(post, payment_method)
          add_echeck_sec_code(post, options)
        end
      end

      def add_customer_token(post, payment_method)
        post[:customer_token] = payment_method
      end

      def add_paymethod_token(post, payment_method)
        post[:paymethod_token] = payment_method
      end

      def commit(http_method, path, params = {})
        url = URI.join(base_url, path)
        body = %i[delete get].include?(http_method) ? nil : params.to_json
        response = JSON.parse(handle_response(raw_ssl_request(http_method, url, body, headers)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, params),
          avs_result: AVSResult.new(code: response['response']['avs_result']),
          cvv_result: CVVResult.new(response['response']['cvv_code']),
          test: test?
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200..499
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(response)
        response['response']['response_code'] == 'A01' ||
          response['response']['response_desc'] == 'Create Successful.' ||
          response['response']['response_desc'] == 'Update Successful.' ||
          response['response']['response_desc'] == 'Delete Successful.' ||
          response['response']['response_desc'] == 'Get Successful.'
      end

      def message_from(response)
        response['response']['response_desc']
      end

      def authorization_from(response, parameters)
        return unless response['transaction_id']

        if parameters[:action] == 'capture'
          [response['transaction_id'], response.dig('response', 'authorization_code'), parameters[:transaction_id], parameters[:authorization_code]].join('#')
        else
          [response['transaction_id'], response.dig('response', 'authorization_code')].join('#')
        end
      end

      def base_url
        URI.join(
          (test? ? test_url : live_url),
          'organizations/',
          "org_#{organization_id.strip}/",
          'locations/',
          "loc_#{@options[:location_id].strip}/"
        )
      end

      def headers
        {
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:api_key]}:#{@options[:secret]}")),
          'X-Forte-Auth-Organization-Id' => "org_#{organization_id}",
          'Content-Type' => 'application/json'
        }
      end

      def format_card_brand(card_brand)
        case card_brand
        when 'visa'
          'visa'
        when 'master'
          'mast'
        when 'american_express'
          'amex'
        when 'discover'
          'disc'
        end
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def authorization_code_from(authorization)
        _, authorization_code, _, original_auth_authorization_code = split_authorization(authorization)
        original_auth_authorization_code.present? ? original_auth_authorization_code : authorization_code
      end

      def transaction_id_from(authorization)
        transaction_id, _, original_auth_transaction_id, = split_authorization(authorization)
        original_auth_transaction_id.present? ? original_auth_transaction_id : transaction_id
      end

      def organization_id
        @options[:organization_id] || @options[:account_id]
      end
    end
  end
end
