module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class PriorityGateway < Gateway
      version 'v3'
      version 'v1', :verify_card_api
      version 'v3', :batch_status_api
      version 'v1', :jwt_api

      # Sandbox and Production
      self.test_url = "https://sandbox.api.mxmerchant.com/checkout/#{fetch_version}/payment"
      self.live_url = "https://api.mxmerchant.com/checkout/#{fetch_version}/payment"

      class_attribute :test_url_verify, :live_url_verify, :test_auth, :live_auth, :test_env_verify, :live_env_verify, :test_url_batch, :live_url_batch, :test_url_jwt, :live_url_jwt, :merchant

      # Sandbox and Production - verify card
      self.test_url_verify = "https://sandbox-api2.mxmerchant.com/merchant/#{fetch_version(:verify_card_api)}/bin"
      self.live_url_verify = "https://api2.mxmerchant.com/merchant/#{fetch_version(:verify_card_api)}/bin"

      # Sandbox and Production - check batch status
      self.test_url_batch = "https://sandbox.api.mxmerchant.com/checkout/#{fetch_version(:batch_status_api)}/batch"
      self.live_url_batch = "https://api.mxmerchant.com/checkout/#{fetch_version(:batch_status_api)}/batch"

      # Sandbox and Production - generate jwt for verify card url
      self.test_url_jwt = "https://sandbox-api2.mxmerchant.com/security/#{fetch_version(:jwt_api)}/application/merchantId"
      self.live_url_jwt = "https://api2.mxmerchant.com/security/#{fetch_version(:jwt_api)}/application/merchantId"

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://mxmerchant.com/'
      self.display_name = 'Priority'

      def initialize(options = {})
        requires!(options, :merchant_id, :api_key, :secret)
        super
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:api_key]}:#{@options[:secret]}")
      end

      def request_headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def request_verify_headers(jwt)
        {
          'Authorization' => "Bearer #{jwt}"
        }
      end

      def purchase(amount, credit_card, options = {})
        params = {}
        params['authOnly'] = false
        params['isSettleFunds'] = true

        add_merchant_id(params)
        add_amount(params, amount, options)
        add_auth_purchase_params(params, options)
        add_credit_card(params, credit_card, 'purchase', options)

        commit('purchase', params:)
      end

      def authorize(amount, credit_card, options = {})
        params = {}
        params['authOnly'] = true
        params['isSettleFunds'] = false

        add_merchant_id(params)
        add_amount(params, amount, options)
        add_auth_purchase_params(params, options)
        add_credit_card(params, credit_card, 'purchase', options)

        commit('purchase', params:)
      end

      def credit(amount, credit_card, options = {})
        params = {}
        params['authOnly'] = false
        params['isSettleFunds'] = true
        amount = -amount

        add_merchant_id(params)
        add_amount(params, amount, options)
        add_credit_params(params, credit_card, options)
        commit('credit', params:)
      end

      def refund(amount, authorization, options = {})
        params = {}
        add_merchant_id(params)
        params['paymentToken'] = payment_token(authorization) || options[:payment_token]

        # refund amounts must be negative
        params['amount'] = ('-' + localized_amount(amount.to_f, options[:currency])).to_f

        commit('refund', params:)
      end

      def capture(amount, authorization, options = {})
        params = {}
        add_merchant_id(params)
        add_amount(params, amount, options)
        params['paymentToken'] = payment_token(authorization) || options[:payment_token]
        add_auth_purchase_params(params, options)

        commit('capture', params:)
      end

      def void(authorization, options = {})
        params = {}

        commit('void', params:, iid: payment_id(authorization))
      end

      def verify(credit_card, _options = {})
        jwt = create_jwt.params['jwtToken']

        commit('verify', card_number: credit_card.number, jwt:)
      end

      def get_payment_status(batch_id)
        commit('get_payment_status', params: batch_id)
      end

      def close_batch(batch_id)
        commit('close_batch', params: batch_id)
      end

      def create_jwt
        commit('create_jwt', params: @options[:merchant_id])
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r((cvv\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_amount(params, amount, options)
        params['amount'] = localized_amount(amount.to_f, options[:currency])
      end

      def add_merchant_id(params)
        params['merchantId'] = @options[:merchant_id]
      end

      def add_auth_purchase_params(params, options)
        add_replay_id(params, options)
        add_purchases_data(params, options)
        add_shipping_data(params, options)
        add_pos_data(params, options)
        add_additional_data(params, options)
      end

      def add_credit_params(params, credit_card, options)
        add_replay_id(params, options)
        add_credit_card(params, credit_card, 'purchase', options)
        add_additional_data(params, options)
      end

      def add_replay_id(params, options)
        params['replayId'] = options[:replay_id] if options[:replay_id]
      end

      def add_credit_card(params, credit_card, action, options)
        return unless credit_card&.is_a?(CreditCard)

        card_details = {}
        card_details['expiryMonth'] = format(credit_card.month, :two_digits).to_s
        card_details['expiryYear'] = format(credit_card.year, :two_digits).to_s
        card_details['cardType'] = credit_card.brand
        card_details['last4'] = credit_card.last_digits
        card_details['cvv'] = credit_card.verification_value unless credit_card.verification_value.nil?
        card_details['number'] = credit_card.number
        card_details['avsStreet'] = options[:billing_address][:address1] if options[:billing_address]
        card_details['avsZip'] =  options[:billing_address][:zip] if !options[:billing_address].nil? && !options[:billing_address][:zip].nil?

        params['cardAccount'] = card_details
      end

      def exp_date(credit_card)
        "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}"
      end

      def add_additional_data(params, options)
        params['isAuth'] = options[:is_auth].present? ? options[:is_auth] : 'true'
        params['paymentType'] = options[:payment_type].present? ? options[:payment_type] : 'Sale'
        params['tenderType'] = options[:tender_type].present? ? options[:tender_type] : 'Card'
        params['taxExempt'] = options[:tax_exempt].present? ? options[:tax_exempt] : 'false'
        params['taxAmount'] = options[:tax_amount] if options[:tax_amount]
        params['shouldGetCreditCardLevel'] = options[:should_get_credit_card_level] if options[:should_get_credit_card_level]
        params['source'] = options[:source] if options[:source]
        params['invoice'] = options[:invoice] if options[:invoice]
        params['isTicket'] = options[:is_ticket] if options[:is_ticket]
        params['shouldVaultCard'] = options[:should_vault_card] if options[:should_vault_card]
        params['sourceZip'] = options[:source_zip] if options[:source_zip]
        params['authCode'] = options[:auth_code] if options[:auth_code]
        params['achIndicator'] = options[:ach_indicator] if options[:ach_indicator]
        params['bankAccount'] = options[:bank_account] if options[:bank_account]
        params['meta'] = options[:meta] if options[:meta]
      end

      def add_pos_data(params, options)
        pos_data = {}
        pos_data['cardholderPresence'] = options.dig(:pos_data, :cardholder_presence) || 'Ecom'
        pos_data['deviceAttendance'] = options.dig(:pos_data, :device_attendance) || 'HomePc'
        pos_data['deviceInputCapability'] = options.dig(:pos_data, :device_input_capability) || 'Unknown'
        pos_data['deviceLocation'] = options.dig(:pos_data, :device_location) || 'HomePc'
        pos_data['panCaptureMethod'] = options.dig(:pos_data, :pan_capture_method) || 'Manual'
        pos_data['partialApprovalSupport'] = options.dig(:pos_data, :partial_approval_support) || 'NotSupported'
        pos_data['pinCaptureCapability'] = options.dig(:pos_data, :pin_capture_capability) || 'Incapable'

        params['posData'] = pos_data
      end

      def add_purchases_data(params, options)
        return unless options[:purchases]

        params['purchases'] = []

        options[:purchases].each do |purchase|
          purchase_object = {}

          purchase_object['name'] = purchase[:name] if purchase[:name]
          purchase_object['description'] = purchase[:description] if purchase[:description]
          purchase_object['code'] = purchase[:code] if purchase[:code]
          purchase_object['unitOfMeasure'] = purchase[:unit_of_measure] if purchase[:unit_of_measure]
          purchase_object['unitPrice'] = purchase[:unit_price] if purchase[:unit_price]
          purchase_object['quantity'] = purchase[:quantity] if purchase[:quantity]
          purchase_object['taxRate'] = purchase[:tax_rate] if purchase[:tax_rate]
          purchase_object['taxAmount'] = purchase[:tax_amount] if purchase[:tax_amount]
          purchase_object['discountRate'] = purchase[:discount_rate] if purchase[:discount_rate]
          purchase_object['discountAmount'] = purchase[:discount_amount] if purchase[:discount_amount]
          purchase_object['extendedAmount'] = purchase[:extended_amount] if purchase[:extended_amount]
          purchase_object['lineItemId'] = purchase[:line_item_id] if purchase[:line_item_id]

          params['purchases'].append(purchase_object)
        end
      end

      def add_shipping_data(params, options)
        params['shipAmount'] = options[:ship_amount] if options[:ship_amount]

        shipping_country = shipping_country_from(options)
        params['shipToCountry'] = shipping_country if shipping_country

        shipping_zip = shipping_zip_from(options)
        params['shipToZip'] = shipping_zip if shipping_zip
      end

      def shipping_country_from(options)
        options[:ship_to_country] || options.dig(:shipping_address, :country) || options.dig(:billing_address, :country)
      end

      def shipping_zip_from(options)
        options[:ship_to_zip] || options.dig(:shipping_addres, :zip) || options.dig(:billing_address, :zip)
      end

      def payment_token(authorization)
        return unless authorization
        return authorization unless authorization.include?('|')

        authorization.split('|').last
      end

      def payment_id(authorization)
        return unless authorization
        return authorization unless authorization.include?('|')

        authorization.split('|').first
      end

      def commit(action, params: '', iid: '', card_number: nil, jwt: '')
        response =
          begin
            case action
            when 'void'
              parse(ssl_request(:delete, url(action, params, ref_number: iid), nil, request_headers))
            when 'verify'
              parse(ssl_get(url(action, params, credit_card_number: card_number), request_verify_headers(jwt)))
            when 'get_payment_status', 'create_jwt'
              parse(ssl_get(url(action, params, ref_number: iid), request_headers))
            when 'close_batch'
              parse(ssl_request(:put, url(action, params, ref_number: iid), nil, request_headers))
            else
              parse(ssl_post(url(action, params), post_data(params), request_headers))
            end
          rescue ResponseError => e
            # currently Priority returns a 404 with no body on certain calls. In those cases we will substitute the response status from response.message
            gateway_response = e.response.body.presence || e.response.message
            parse(gateway_response)
          end

        success = success_from(response, action)
        Response.new(
          success,
          message_from(response),
          response,
          authorization: success ? authorization_from(response) : nil,
          error_code: success || response == '' ? nil : error_from(response),
          test: test?
        )
      end

      def url(action, params, ref_number: '', credit_card_number: nil)
        case action
        when 'void'
          base_url + "/#{ref_number}?force=true"
        when 'verify'
          (verify_url + '?search=') + credit_card_number.to_s[0..7]
        when 'get_payment_status', 'close_batch'
          batch_url + "/#{params}"
        when 'create_jwt'
          jwt_url + "/#{params}/token"
        else
          base_url + '?includeCustomerMatches=false&echo=true'
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def verify_url
        test? ? self.test_url_verify : self.live_url_verify
      end

      def jwt_url
        test? ? self.test_url_jwt : self.live_url_jwt
      end

      def batch_url
        test? ? self.test_url_batch : self.live_url_batch
      end

      def handle_response(response)
        case response.code.to_i
        when 204
          { status: 'Success' }.to_json
        when 200...300
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def parse(body)
        return {} if body.blank?

        parsed_response = JSON.parse(body)
        parsed_response.is_a?(String) ? { 'message' => parsed_response } : parsed_response
      rescue JSON::ParserError
        message = 'Invalid JSON response received from Priority Gateway. Please contact Priority Gateway if you continue to receive this message.'
        message += " (The raw response returned by the API was #{body.inspect})"
        {
          'message' => message
        }
      end

      def success_from(response, action)
        return !response['bank'].empty? if action == 'verify' && response['bank'] && !response.dig('bank', 'name').blank?

        %w[Approved Open Success Settled Voided].include?(response['status'])
      end

      def message_from(response)
        return response['details'][0] if response['details'] && response['details'][0]

        response['authMessage'] || response['message'] || response['status']
      end

      def authorization_from(response)
        [response['id'], response['paymentToken']].join('|')
      end

      def error_from(response)
        response['errorCode'] || response['status']
      end

      def post_data(params)
        params.to_json
      end
    end
  end
end
