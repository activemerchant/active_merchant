module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FinixGateway < Gateway
      include Empty

      SUCCESS_CODES = [200, 201].freeze
      COUNTRY_CODE  = { 'US' => 'USA', 'CA' => 'CAN' }.freeze

      self.test_url = 'https://finix.sandbox-payments-api.com'
      self.live_url = 'https://www.finixpayments.com'
      self.supported_countries = %w[US CA]
      self.supported_cardtypes = %i[visa master american_express discover]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.homepage_url = 'https://finixpayments.com'
      self.display_name = 'Finix'

      def initialize(options = {})
        requires!(options, :username, :password, :merchant_id)
        super
        @username = options[:username]
        @password = options[:password]
        @merchant_id = options[:merchant_id]
      end

      def purchase(amount, payment_source, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_source(post, payment_source, options)
        add_idempotency_id(post, options)

        verification_data = options[:verification_data] || {}
        commit('transaction', post, verification_data, options)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_refund_data(post, amount, authorization, options)

        commit('reversals', post, options)
      end

      private

      def add_payment_source(post, payment_source, options)
        return attach_existing_instrument(post, payment_source, options) if existing_customer?(options)

        identity = create_new_identity(options)
        return identity unless identity.success?

        attach_new_instrument(post, identity.authorization, payment_source, options)
      end

      def existing_customer?(options)
        options[:customer_identity].present?
      end

      def attach_existing_instrument(post, payment_source, options)
        instrument_id = payment_source[:finix_payment_instrument_id]

        if instrument_id.present?
          attach_existing_instrument_data(post, instrument_id, options)
        else
          create_and_attach_new_instrument(post, payment_source, options)
        end
      end

      def attach_existing_instrument_data(post, instrument_id, options)
        payment_instrument = fetch_payment_instrument(instrument_id)

        options[:verification_data] = {
          avs_result: payment_instrument.dig('address_verification'),
          cvv_result: payment_instrument.dig('security_code_verification')
        }

        post[:instrument_id] = instrument_id
      end

      def create_and_attach_new_instrument(post, payment_source, options)
        instrument = create_payment_instrument(options[:customer_identity], payment_source, options)

        return instrument unless instrument.success?

        post[:instrument_id] = instrument.params['id']
      end

      def create_new_identity(options)
        identity = create_identity(options)
        options[:identity_id] = identity.authorization if identity.success?
        identity
      end

      def attach_new_instrument(post, identity_id, payment_source, options)
        instrument = create_payment_instrument(identity_id, payment_source, options)
        return instrument unless instrument.success?

        options[:verification_data] = {
          avs_result: instrument.params['address_verification'],
          cvv_result: instrument.params['security_code_verification']
        }

        post[:instrument_id] = instrument.params['id']
      end

      def create_identity(options)
        post = {}
        add_identity_data(post, options)

        commit('identities', post, nil, options)
      end

      def create_payment_instrument(identity_id, payment_source, options)
        post = {}
        post[:identity] = identity_id
        add_payment_method(post, payment_source, options)
        add_address(post, options)

        commit('payment_instruments', post, nil, options)
      end

      def fetch_payment_instrument(payment_instrument_id)
        raw_response = ssl_get("#{url}/payment_instruments/#{payment_instrument_id}", headers)
        response = parse(raw_response)
      end

      def add_refund_data(post, amount, authorization, options)
        post[:amount] = amount
        post[:transaction_id] = authorization
        add_idempotency_id(post, options) if options['idempotency_id'].present?
      end

      def add_idempotency_id(post, options)
        post[:idempotency_id] = options['idempotency_id']
      end

      def add_identity_data(post, options)
        billing               = options[:billing_address] || {}
        post[:type]           = 'BUSINESS'
        post[:identity_roles] = ['BUYER']
        post[:entity]         = {
                                  first_name: extract_first_name(billing[:name]),
                                  last_name: extract_last_name(billing[:name]),
                                  email: options[:email],
                                  phone: billing[:phone],
                                  personal_address: build_address(billing)
                                }
      end

      def add_payment_method(post, payment_source, options)
        billing                 = options[:billing_address] || {}
        post[:type]             = 'PAYMENT_CARD'
        post[:name]             = billing[:name]
        post[:number]           = payment_source.number
        post[:expiration_month] = payment_source.month
        post[:expiration_year]  = payment_source.year
        post[:security_code]    = payment_source.verification_value
      end

      def add_invoice(post, amount, options)
        post[:amount]   = amount
        post[:currency] = options[:currency] || default_currency
        post[:merchant] = @merchant_id
        post[:tags] = {
            purpose: 'sale',
            order_id: options[:order_id],
            customer_id: options[:customer_id]
          }.compact
      end

      def add_address(post, options)
        billing        = options[:billing_address] || {}
        post[:address] = build_address(billing)
      end

      def add_reference(post, authorization)
        post[:transaction_id] = authorization
      end

      def build_address(data)
        {
          line1: data[:address1],
          city: data[:city],
          region: data[:state],
          postal_code: data[:zip].to_s.gsub(/\s+/, ''),
          country: COUNTRY_CODE[data[:country]] || data[:country]
        }
      end

      def commit(action, params, verification_data = nil, options = {})
        request_url  = build_request_url(action, params)
        payload      = build_payload(action, params)
        raw_response = ssl_post(request_url, payload.to_json, headers)
        response     = parse(raw_response).merge('customer_identity' => options[:identity_id]).compact
        succeeded    = ['identities', 'payment_instruments'].include?(action) ?
                        profile_created_successful?(response) :
                        success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          error_code: error_code_from(succeeded, response),
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: verification_data&.dig(:avs_result)),
          cvv_result: CVVResult.new(verification_data&.dig(:cvv_result)),
          test: test?,
          response_type: response_type(response['state']),
          response_http_code: @response_http_code,
          request_endpoint: request_url,
          request_method: :post,
          request_body: payload
        )
      end

      def build_request_url(action, params)
        case action
        when 'identities'
          "#{url}/identities"
        when 'payment_instruments'
          "#{url}/payment_instruments"
        when 'transaction'
          "#{url}/transfers"
        when 'reversals'
          "#{url}/transfers/#{params[:transaction_id]}/reversals"
        end
      end

      def build_payload(action, params)
        case action
        when 'reversals'
          {
            amount: params[:amount],
            idempotency_id: params[:idempotency_id],
            tags: params[:tags]
          }
        when 'transaction'
          {
            amount: params[:amount],
            currency: params[:currency] || default_currency,
            merchant: @merchant_id,
            source: params[:instrument_id],
            idempotency_id: params[:idempotency_id],
            tags: params[:tags]
          }
        else
          params
        end
      end

      def headers
        {
          'Content-Type'  => 'application/json',
          'Authorization' => "Basic #{Base64.strict_encode64("#{@username}:#{@password}")}",
          'Finix-Version' => '2018-01-01'
        }
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response['state'] == 'SUCCEEDED'
      end

      def profile_created_successful?(response)
        return true if response['id'].present?

        errors = response.dig('_embedded', 'errors')
        if errors.present?
          return false
        end

        false
      end

      def message_from(succeeded, response)
        return 'Succeeded' if succeeded

        embedded_errors = response.dig('_embedded', 'errors')
        if embedded_errors.present? && embedded_errors.first['message'].present?
          return embedded_errors.first['message']
        end

        response['state']&.capitalize || 'Failed'
      end


      def error_code_from(succeeded, response)
        return nil if succeeded

        error_code = response.dig('_embedded', 'errors', 0, 'code')
        error_code || 'UNKNOWN_ERROR'
      end

      def authorization_from(response)
        response['id']
      end

      def response_type(state)
        case state
        when 'SUCCEEDED'            then 0
        when 'FAILED'               then 2
        when 'CANCELED', 'DECLINED' then 1
        else 1
        end
      end

      def extract_first_name(name)
        name.to_s.split.first
      end

      def extract_last_name(name)
        name.to_s.split[1..]&.join(' ')
      end
    end
  end
end





