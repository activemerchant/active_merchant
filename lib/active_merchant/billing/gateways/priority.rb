module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PriorityGateway < Gateway
      self.test_url = 'https://qa.api.mxmerchant.com/checkout/v3/payment'
      self.live_url = 'https://qa.api.mxmerchant.com/checkout/v3/payment'

      class_attribute :test_url_verify, :live_url_verify, :test_auth, :live_auth, :test_env_verify, :live_env_verify, :test_url_batch, :live_url_batch, :merchant

      self.test_url_verify = 'Contact priority for url'
      self.live_url_verify = 'Contact priority for url'

      self.test_url_batch = 'https://qa.api.mxmerchant.com/checkout/v3/batch'
      self.live_url_batch = 'https://qa.api.mxmerchant.com/checkout/v3/batch'

      self.test_auth = 'Contact priority for token'
      self.live_auth = 'Contact priority for token'

      self.test_env_verify = 'qa-aus'
      self.live_env_verify = 'qa-aus'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://mxmerchant.com/'
      self.display_name = 'Priority'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        super
      end

      def basic_auth(key, secret)
        Base64.strict_encode64("#{key}:#{secret}")
      end

      def request_headers(options)
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth(options[:key], options[:secret])}"
        }
      end

      def request_verify_headers
        auth = test? ? self.test_auth : self.live_auth
        env_verify = test? ? self.test_env_verify : self.live_env_verify
        {
          'Authorization' => auth.to_s,
          'EOS-Virtual-Environment' => env_verify.to_s
        }
      end

      def purchase(amount, credit_card, options = {})
        params = {}
        add_bank_amount_purchase(params, amount, false)
        add_credit_card(params, credit_card, 'purchase', options)
        add_type_merchant_purchase(params, options[:merchant], true, options)
        commit('purchase', params, '', '', options)
      end

      def authorize(amount, credit_card, options = {})
        params = {}
        add_bank_amount_purchase(params, amount, true)
        add_credit_card(params, credit_card, 'purchase', options)
        add_type_merchant_purchase(params, options[:merchant], false, options)
        commit('purchase', params, '', '', options)
      end

      def refund(amount, credit_card, options)
        params = {}

        add_bank_amount_refund(params, amount, options[:authCode])
        add_credit_card(params, credit_card, 'refund', options)
        add_type_merchant_refund(params, options)
        commit('refund', params, '', '', options)
      end

      def capture(amount, authorization, options = {})
        params = {}
        params['amount'] = amount
        params['authCode'] = options[:authCode]
        params['merchantId'] = options[:merchant]
        params['paymentToken'] = authorization
        params['shouldGetCreditCardLevel'] = true
        params['source'] = 'Spreedly'
        params['tenderType'] = 'Card'

        commit('capture', params, '', '', options)
      end

      def void(iid, options)
        commit('void', '', iid, '', options)
      end

      def verify(creditcardnumber)
        commit('verify', '', '', creditcardnumber, '')
      end

      def supports_scrubbing?
        true
      end

      def getpaymentstatus(batchid, options)
        commit('getpaymentstatus', batchid, '', '', options)
      end

      def closebatch(batchid, options)
        commit('closebatch', batchid, '', '', options)
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((number)\W+\d+), '\1[FILTERED]').
          gsub(%r((cvv)\W+\d+), '\1[FILTERED]')
      end

      def add_bank_amount_purchase(params, amount, authOnly)
        params['achIndicator'] = nil
        params['amount'] = amount
        params['authCode'] = nil
        params['authOnly'] = authOnly
        params['bankAccount'] = nil
      end

      def add_bank_amount_refund(params, amount, authCode)
        params['amount'] = amount
        params['authCode'] = authCode
        params['authMessage'] = ''
        params['authOnly'] = false
        params['availableAuthAmount'] = 0
        params['batch'] = nil
        params['batchId'] = nil
      end

      def add_credit_card(params, credit_card, action, options)
        return unless credit_card

        params['cardAccount'] ||= {}
        card_details = params['cardAccount'] = {}

        case action
        when 'purchase'
          card_details['avsStreet'] = options[:avsStreet]
          card_details['avsZip'] = options[:avsZip]
          card_details['cvv'] = credit_card.verification_value
          card_details['entryMode'] = 'Keyed'
          card_details['expiryDate'] = expdate(credit_card)
          card_details['expiryMonth'] = format(credit_card.month, :two_digits).to_s
          card_details['expiryYear'] = format(credit_card.year, :two_digits).to_s
          card_details['last4'] = nil
          card_details['magstripe'] = nil
          card_details['number'] = credit_card.number
        when 'refund'
          card_details['cardId'] = credit_card['cardId']
          card_details['cardPresent'] = credit_card['cardPresent']
          card_details['cardType'] = credit_card['cardType']
          card_details['entryMode'] = credit_card['entryMode']
          card_details['expiryMonth'] = credit_card['expiryMonth']
          card_details['expiryYear'] = credit_card['expiryYear']
          card_details['hasContract'] = credit_card['hasContract']
          card_details['isCorp'] = credit_card['isCorp']
          card_details['isDebit'] = credit_card['isDebit']
          card_details['last4'] = credit_card['last4']
          card_details['token'] = credit_card['token']
        end
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}"
      end

      @request_params = {
        achIndicator: nil,
        authCode: nil,
        authOnly: false,
        bankAccount: nil,
        cardPresent: false,
        cardPresentType: 'CardNotPresent',
        isAuth: true,
        isSettleFunds: true,
        isTicket: false,
        merchantId: 514_391_592,
        mxAdvantageEnabled: false,
        mxAdvantageFeeLabel: '',
        paymentType: 'Sale',
        purchases: [{ taxRate: '0.0000', additionalTaxRate: nil, discountRate: nil }],
        shouldGetCreditCardLevel: true,
        shouldVaultCard: true,
        source: 'QuickPay',
        sourceZip: '94102',
        taxExempt: false,
        tenderType: 'Card',
        terminals: []
      }
      def purchases
        [{ taxRate: '0.0000', additionalTaxRate: nil, discountRate: nil }]
      end

      def add_type_merchant_purchase(params, merchant, isSettleFunds, options)
        params['cardPresent'] = false
        params['cardPresentType'] = 'CardNotPresent'
        params['isAuth'] = true
        params['isSettleFunds'] = isSettleFunds
        params['isTicket'] = false

        params['merchantId'] = merchant
        params['mxAdvantageEnabled'] = false
        params['mxAdvantageFeeLabel'] = ''
        params['paymentType'] = 'Sale'
        params['bankAccount'] = nil

        params['purchases'] = purchases
        params['shouldGetCreditCardLevel'] = true
        params['shouldVaultCard'] = true
        params['source'] = 'Spreedly'
        params['sourceZip'] = options[:billing_address][:zip]
        params['taxExempt'] = false
        params['tenderType'] = 'Card'
        params['terminals'] = []
      end

      def add_type_merchant_refund(params, options)
        params['cardPresent'] = options['cardPresent']
        params['clientReference'] = options['clientReference']
        params['created'] = options['created']
        params['creatorName'] = options['creatorName']
        params['currency'] = options['currency']
        params['customerCode'] = options['customerCode']
        params['enteredAmount'] = options['amount']
        params['id'] = 0
        params['invoice'] = options['invoice']
        params['isDuplicate'] = false
        params['merchantId'] = options['merchantId']
        params['paymentToken'] = options['cardAccount']['token']

        params['posData'] = options['posData']

        params['purchases'] = options['purchases']

        params['reference'] = options['reference']
        params['replayId'] = nil
        params['requireSignature'] = false
        params['reviewIndicator'] = nil

        params['risk'] = options['risk']

        params['settledAmount'] = options['settledAmount']
        params['settledCurrency'] = options['settledCurrency']
        params['settledDate'] = options['created']
        params['shipToCountry'] = options['shipToCountry']
        params['shouldGetCreditCardLevel'] = options['shouldGetCreditCardLevel']
        params['source'] = 'Spreedly'
        params['sourceZip'] = nil
        params['status'] = options['status']
        params['tax'] = options['tax']
        params['taxExempt'] = options['taxExempt']
        params['tenderType'] = 'Card'
        params['type'] = options['type']
      end

      def commit(action, params, iid, creditcardnumber, options)
        response =
          begin
            if action == 'void' || action == 'closebatch'
              ssl_invoke(action, params, iid, creditcardnumber, options)
            else
              parse(ssl_invoke(action, params, iid, creditcardnumber, options))
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
        else

          if response.code == '204' || response == ''
            response.body = { 'code' => '204' }
          else
            raise ResponseError.new(response)
          end
        end
      end

      def ssl_invoke(action, params, refnumber, creditcardnumber, options)
        if action == 'void'
          ssl_request(:delete, url(action, params, refnumber, ''), nil, request_headers(options))
        else
          if action == 'verify'
            ssl_get(url(action, params, '', creditcardnumber), request_verify_headers)
          else
            if action == 'getpaymentstatus'
              ssl_get(url(action, params, refnumber, ''), request_headers(options))
            else
              if action == 'closebatch'
                ssl_request(:put, url(action, params, refnumber, ''), nil, request_headers(options))
              else
                ssl_post(url(action, params), post_data(params), request_headers(options))
                end
            end
          end
        end
      end

      def url(action, params, refnumber = '', creditcardnumber = '')
        base_url = test? ? test_url : live_url
        base_url_verify = test? ? self.test_url_verify : self.live_url_verify
        base_url_batch = test? ? self.test_url_batch : self.live_url_batch

        if action == 'void'
          base_url += "?id=#{refnumber}&force=true"
        else
          if action == 'verify'
            base_url = base_url_verify + (creditcardnumber[0, 6]).to_s
          else
            if action == 'getpaymentstatus' || action == 'closebatch'
              base_url = base_url_batch + "/#{params}"
            else
              base_url + '?includeCustomerMatches=false&echo=true'
            end
          end
        end
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
        return true if response['paymentToken'] || response['status'] == 'Approved' || response['code'] == '204' || response['tenderType'] == 'Card' || response == ''
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
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
    end
  end
end
