module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PriorityGateway < Gateway
      # Sandbox and Production
      self.test_url = 'https://sandbox.api.mxmerchant.com/checkout/v3/payment'
      self.live_url = 'https://api.mxmerchant.com/checkout/v3/payment'

      class_attribute :test_url_verify, :live_url_verify, :test_auth, :live_auth, :test_env_verify, :live_env_verify, :test_url_batch, :live_url_batch, :test_url_jwt, :live_url_jwt, :merchant

      # Sandbox and Production - verify card
      self.test_url_verify = 'https://sandbox-api2.mxmerchant.com/merchant/v1/bin'
      self.live_url_verify = 'https://api2.mxmerchant.com/merchant/v1/bin'

      # Sandbox and Production - check batch status
      self.test_url_batch = 'https://sandbox.api.mxmerchant.com/checkout/v3/batch'
      self.live_url_batch = 'https://api.mxmerchant.com/checkout/v3/batch'

      # Sandbox and Production - generate jwt for verify card url
      self.test_url_jwt = 'https://sandbox-api2.mxmerchant.com/security/v1/application/merchantId'
      self.live_url_jwt = 'https://api2.mxmerchant.com/security/v1/application/merchantId'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://mxmerchant.com/'
      self.display_name = 'Priority'

      def initialize(options = {})
        requires!(options, :merchant_id, :key, :secret)
        super
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:key]}:#{@options[:secret]}")
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
        params['amount'] = localized_amount(amount.to_f, options[:currency])
        params['authOnly'] = false

        add_credit_card(params, credit_card, 'purchase', options)
        add_type_merchant_purchase(params, @options[:merchant_id], true, options)
        commit('purchase', params: params, jwt: options)
      end

      def authorize(amount, credit_card, options = {})
        params = {}
        params['amount'] = localized_amount(amount.to_f, options[:currency])
        params['authOnly'] = true

        add_credit_card(params, credit_card, 'purchase', options)
        add_type_merchant_purchase(params, @options[:merchant_id], false, options)
        commit('purchase', params: params, jwt: options)
      end

      def refund(amount, credit_card, options)
        params = {}
        # refund amounts must be negative
        params['amount'] = ('-' + localized_amount(amount.to_f, options[:currency])).to_f

        add_bank(params, options[:auth_code])
        add_credit_card(params, credit_card, 'refund', options) unless options[:auth_code]
        add_type_merchant_refund(params, options)
        commit('refund', params: params, jwt: options)
      end

      def capture(amount, authorization, options = {})
        params = {}
        params['amount'] = localized_amount(amount.to_f, options[:currency])
        params['authCode'] = options[:authCode]
        params['merchantId'] = @options[:merchant_id]
        params['paymentToken'] = authorization
        params['shouldGetCreditCardLevel'] = true
        params['source'] = options['source']
        params['tenderType'] = options[:tender_type]

        commit('capture', params: params, jwt: options)
      end

      def void(iid, options)
        commit('void', iid: iid, jwt: options)
      end

      def verify(credit_card, jwt)
        commit('verify', card_number: credit_card, jwt: jwt)
      end

      def supports_scrubbing?
        true
      end

      def get_payment_status(batch_id, options)
        commit('get_payment_status', params: batch_id, jwt: options)
      end

      def close_batch(batch_id, options)
        commit('close_batch', params: batch_id, jwt: options)
      end

      def create_jwt(options)
        commit('create_jwt', params: @options[:merchant_id], jwt: options)
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r((cvv\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      def add_bank(params, auth_code)
        params['authCode'] = auth_code
        params['authOnly'] = false
        params['availableAuthAmount'] = 0
      end

      def add_credit_card(params, credit_card, action, options)
        return unless credit_card

        card_details = {}

        card_details['expiryMonth'] = format(credit_card.month, :two_digits).to_s
        card_details['expiryYear'] = format(credit_card.year, :two_digits).to_s
        card_details['expiryDate'] = exp_date(credit_card)
        card_details['cardType'] = credit_card.brand
        card_details['last4'] = credit_card.last_digits
        card_details['cvv'] = credit_card.verification_value
        card_details['number'] = credit_card.number

        card_details['entryMode'] = options['entryMode'].blank? ? 'Keyed' : options['entryMode']

        case action
        when 'purchase'
          card_details['avsStreet'] = options[:billing_address][:address1]
          card_details['avsZip'] =  options[:billing_address][:zip]
        when 'refund'
          card_details['cardId'] = options[:card_id]
          card_details['cardPresent'] = options[:card_present]
          card_details['hasContract'] = options[:has_contract]
          card_details['isCorp'] = options[:is_corp]
          card_details['isDebit'] = options[:is_debit]
          card_details['token'] = options[:token]
        else
          card_details
        end

        params['cardAccount'] = card_details
      end

      def exp_date(credit_card)
        "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}"
      end

      def purchases
        [{ taxRate: '0.0000', additionalTaxRate: nil, discountRate: nil }]
      end

      def add_type_merchant_purchase(params, merchant, is_settle_funds, options)
        params['cardPresent'] = false
        params['cardPresentType'] = 'CardNotPresent'
        params['isAuth'] = true
        params['isSettleFunds'] = is_settle_funds
        params['isTicket'] = false

        params['merchantId'] = merchant
        params['mxAdvantageEnabled'] = false
        params['paymentType'] = 'Sale'

        params['purchases'] = purchases

        params['shouldGetCreditCardLevel'] = true
        params['shouldVaultCard'] = true
        params['source'] = options['source']
        params['sourceZip'] = options[:billing_address][:zip]
        params['taxExempt'] = false
        params['tenderType'] = options[:tender_type]
      end

      def add_type_merchant_refund(params, options)
        params['cardPresent'] = options[:card_present]
        params['clientReference'] = options[:client_ref]
        params['created'] = options[:created]
        params['creatorName'] = options[:creator_name]
        params['currency'] = options[:currency]
        params['customerCode'] = options[:customer_code]
        params['enteredAmount'] = options[:amount]
        params['id'] = 0
        params['invoice'] = options[:invoice]
        params['isDuplicate'] = false
        params['merchantId'] = @options[:merchant_id]
        params['paymentToken'] = options[:payment_token]

        params['posData'] = add_pos_data(options[:pos_data]) if options[:pos_data]

        params['purchases'] = add_purchases_data(options[:purchases][0]) if options[:purchases]

        params['reference'] = options[:reference]
        params['requireSignature'] = false

        params['risk'] = add_risk_data(options[:risk]) if options[:risk]

        params['settledAmount'] = options[:settled_amt]
        params['settledCurrency'] = options[:settled_currency]
        params['settledDate'] = options[:created]
        params['shipToCountry'] = options[:ship_to_country]
        params['shouldGetCreditCardLevel'] = options[:should_get_credit_card_level]
        params['source'] = options[:source]
        params['status'] = options[:status]
        params['tax'] = options[:tax]
        params['taxExempt'] = options[:tax_exempt]
        params['tenderType'] = options[:tender_type]
        params['type'] = options[:type]
      end

      def commit(action, params: '', iid: '', card_number: nil, jwt: '')
        response =
          begin
            case action
            when 'void'
              ssl_request(:delete, url(action, params, ref_number: iid), nil, request_headers)
            when 'verify'
              parse(ssl_get(url(action, params, credit_card_number: card_number), request_verify_headers(jwt)))
            when 'get_payment_status', 'create_jwt'
              parse(ssl_get(url(action, params, ref_number: iid), request_headers))
            when 'close_batch'
              ssl_request(:put, url(action, params, ref_number: iid), nil, request_headers)
            else
              parse(ssl_post(url(action, params), post_data(params), request_headers))
            end
          rescue ResponseError => e
            parse(e.response.body)
          end
        success = success_from(response)

        response = { 'code' => '204' } if response == ''
        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: success && response['code'] != '204' ? authorization_from(response) : nil,
          error_code: success || response['code'] == '204' || response == '' ? nil : error_from(response),
          test: test?
        )
      end

      def handle_response(response)
        if response.code != '204' && (200...300).cover?(response.code.to_i)
          response.body
        elsif response.code == '204' || response == ''
          response.body = { 'code' => '204' }
        else
          raise ResponseError.new(response)
        end
      end

      def url(action, params, ref_number: '', credit_card_number: nil)
        case action
        when 'void'
          base_url + "/#{ref_number}?force=true"
        when 'verify'
          (verify_url + '?search=') + credit_card_number.to_s[0..6]
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

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        message = 'Invalid JSON response received from Priority Gateway. Please contact Priority Gateway if you continue to receive this message.'
        message += " (The raw response returned by the API was #{body.inspect})"
        {
          'message' => message
        }
      end

      def success_from(response)
        response['status'] == 'Approved' || response['status'] == 'Open' if response['status']
      end

      def message_from(succeeded, response)
        if succeeded
          response['status']
        else
          response['authMessage']
        end
      end

      def authorization_from(response)
        response['paymentToken']
      end

      def error_from(response)
        response['errorCode']
      end

      def post_data(params)
        params.to_json
      end

      def add_pos_data(options)
        pos_options = {}
        pos_options['panCaptureMethod'] = options[:pan_capture_method]

        pos_options
      end

      def add_purchases_data(options)
        purchases = {}

        purchases['dateCreated'] = options[:date_created]
        purchases['iId'] = options[:i_id]
        purchases['transactionIId'] = options[:transaction_i_id]
        purchases['transactionId'] = options[:transaction_id]
        purchases['name'] = options[:name]
        purchases['description'] = options[:description]
        purchases['code'] = options[:code]
        purchases['unitOfMeasure'] = options[:unit_of_measure]
        purchases['unitPrice'] = options[:unit_price]
        purchases['quantity'] = options[:quantity]
        purchases['taxRate'] = options[:tax_rate]
        purchases['taxAmount'] = options[:tax_amount]
        purchases['discountRate'] = options[:discount_rate]
        purchases['discountAmount'] = options[:discount_amt]
        purchases['extendedAmount'] = options[:extended_amt]
        purchases['lineItemId'] = options[:line_item_id]

        purchase_arr = []
        purchase_arr[0] = purchases
        purchase_arr
      end

      def add_risk_data(options)
        risk = {}
        risk['cvvResponseCode'] = options[:cvv_response_code]
        risk['cvvResponse'] = options[:cvv_response]
        risk['cvvMatch'] = options[:cvv_match]
        risk['avsResponse'] = options[:avs_response]
        risk['avsAddressMatch'] = options[:avs_address_match]
        risk['avsZipMatch'] = options[:avs_zip_match]

        risk
      end
    end
  end
end
