module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Shift4Gateway < Gateway
      self.test_url = 'https://utgapi.shift4test.com/api/rest/v1/'
      self.live_url = 'https://utg.shift4api.net/api/rest/v1/'

      self.supported_countries = %w(US CA CU HT DO PR JM TT GP MQ BS BB LC CW AW VC VI GD AG DM KY KN SX TC MF VG BQ AI BL MS)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://shift4.com'
      self.display_name = 'Shift4'

      RECURRING_TYPE_TRANSACTIONS = %w(recurring installment)
      TRANSACTIONS_WITHOUT_RESPONSE_CODE = %w(accesstoken add)
      SUCCESS_TRANSACTION_STATUS = %w(A R)
      URL_POSTFIX_MAPPING = {
        'accesstoken' => 'credentials',
        'add' => 'tokens',
        'verify' => 'cards'
      }
      STANDARD_ERROR_CODE_MAPPING = {
        'incorrect_number' => STANDARD_ERROR_CODE[:incorrect_number],
        'invalid_number' => STANDARD_ERROR_CODE[:invalid_number],
        'invalid_expiry_month' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_expiry_year' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_cvc' => STANDARD_ERROR_CODE[:invalid_cvc],
        'expired_card' => STANDARD_ERROR_CODE[:expired_card],
        'insufficient_funds' => STANDARD_ERROR_CODE[:card_declined],
        'incorrect_cvc' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'incorrect_zip' => STANDARD_ERROR_CODE[:incorrect_zip],
        'card_declined' => STANDARD_ERROR_CODE[:card_declined],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
        'lost_or_stolen' => STANDARD_ERROR_CODE[:card_declined],
        'suspected_fraud' => STANDARD_ERROR_CODE[:card_declined],
        'expired_token' => STANDARD_ERROR_CODE[:card_declined]
      }

      def initialize(options = {})
        requires!(options, :client_guid, :auth_token)
        @client_guid = options[:client_guid]
        @auth_token = options[:auth_token]
        super
        @access_token = setup_access_token
      end

      def purchase(money, payment_method, options = {})
        post = {}

        payment_method = get_card_token(payment_method) if payment_method.is_a?(String)
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(post, payment_method, options)
        add_card_present(post, options)
        add_three_d_secure(post, payment_method, options)

        commit('sale', post, options)
      end

      def authorize(money, payment_method, options = {})
        post = {}
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(post, payment_method, options)
        add_card_present(post, options)
        add_three_d_secure(post, payment_method, options)
        add_customer(post, options)

        commit('authorization', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(post, get_card_token(authorization), options)

        commit('capture', post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_customer(post, options)
        add_card(post, get_card_token(authorization), options)

        commit('refund', post, options)
      end

      def void(authorization, options = {})
        options[:invoice] = get_invoice(authorization)
        commit('invoice', {}, options)
      end

      def verify(credit_card, options = {})
        post = {}
        add_card(post, credit_card, options)

        commit('verify', post, options)
      end

      def store(credit_card, options = {})
        post = {}
        add_datetime(post, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(post, credit_card, options)

        commit('add', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(("Number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("expirationDate\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("FirstName\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("LastName\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("securityCode":{"[\w]+":"[\w]+","value":")[\d]*)i, '\1[FILTERED]')
      end

      private

      def add_credentials(post, options)
        post[:credential] = {}
        post[:credential][:clientGuid] = @client_guid
        post[:credential][:authToken] = @auth_token
      end

      def setup_access_token
        post = {}
        add_credentials(post, options)
        add_datetime(post, options)

        response = commit('accesstoken', post, request_headers(options))
        response.params['result'].first['credential']['accessToken']
      end

      def add_three_d_secure(post, payment_method, options)
        return unless three_d_secure = options[:three_d_secure]

        post[:threeDSecure] = {}
        post[:threeDSecure][:cryptogram] = payment_method.payment_cryptogram if payment_method.is_a?(NetworkTokenizationCreditCard)
        post[:threeDSecure][:ecommIndicator] = three_d_secure[:eci] || payment_method.eci if three_d_secure[:eci] || (payment_method.is_a?(NetworkTokenizationCreditCard) && payment_method.eci)
        post[:threeDSecure][:securityLevelIndicator] = options[:security_level_indicator] || '241'
        post[:threeDSecure][:xid] = three_d_secure[:xid] if three_d_secure[:xid]
        post[:threeDSecure][:programProtocol] = three_d_secure[:version][0, 1] if three_d_secure[:version]
        post[:threeDSecure][:authenticationSource] = options[:authentication_source] if options[:authentication_source]
        post[:threeDSecure][:cavvResult] = options[:cavv_result] if options[:cavv_result]
        post[:threeDSecure][:authenticationValue] = three_d_secure[:cavv] if three_d_secure[:cavv]
        post[:threeDSecure][:tavvResult] = options[:tavv_result] if options[:tavv_result]
        post[:threeDSecure][:directoryServerTranId] = three_d_secure[:ds_transaction_id] if three_d_secure[:ds_transaction_id]
        post[:threeDSecure][:walletID] = options[:wallet_id] if options[:wallet_id]
      end

      def add_clerk(post, options)
        post[:clerk] = {}
        post[:clerk][:numericId] = options[:clerk_id]
      end

      def add_invoice(post, money, options)
        post[:amount] = {}
        post[:amount][:total] = amount(money.to_f)
        post[:amount][:tax] = options[:tax].to_f || 0.0
      end

      def add_datetime(post, options)
        post[:dateTime] = options[:date_time] || current_date_time
      end

      def add_transaction(post, options)
        post[:transaction] = {}
        post[:transaction][:invoice] = options[:invoice] || rand.to_s[2..11]
        post[:transaction][:notes] = options[:notes] if options[:notes].present?

        add_purchase_card(post[:transaction], options)
        add_card_on_file(post[:transaction], options)
      end

      def add_card(post, payment_method, options)
        post[:card] = {}
        post[:card][:entryMode] = options[:entry_mode] || 'M'
        if payment_method.is_a?(CreditCard)
          post[:card][:expirationDate] = "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
          post[:card][:number] = payment_method.number
          post[:card][:entryMode] = options[:entry_mode]
          post[:card][:securityCode] = {}
          post[:card][:securityCode][:indicator] = 1
          post[:card][:securityCode][:value] = payment_method.verification_value
        else
          post[:card] = {} if post[:card].nil?
          post[:card][:token] = {}
          post[:card][:token][:value] = payment_method
        end
      end

      def add_card_present(post, options)
        post[:card] = {} unless post[:card].present?

        post[:card][:present] = options[:card_present] || 'N'
      end

      def add_customer(post, options)
        if address = options[:billing_address]
          post[:customer] = {}
          post[:customer][:addressLine1] = address[:address1] if address[:address1]
          post[:customer][:postalCode] = address[:zip]
          name = address[:name].split(' ') if address[:name]
          if name&.is_a?(Array)
            post[:customer][:firstName] = name[0]
            post[:customer][:lastName] = name[1]
          end
        end
      end

      def add_purchase_card(post, options)
        post[:purchaseCard] = {}
        post[:purchaseCard][:customerReference] = options[:customer_reference]
        post[:purchaseCard][:destinationPostalCode] = options[:destination_postal_code]
        post[:purchaseCard][:productDescriptors] = options[:product_descriptors]
      end

      def add_card_on_file(post, options)
        return unless stored_credential = options[:stored_credential]

        post[:cardOnFile] = {}
        post[:cardOnFile][:usageIndicator] = stored_credential[:inital_transaction] ? '01' : '02'
        post[:cardOnFile][:indicator] = options[:card_on_file_indicator] || '01'
        post[:cardOnFile][:scheduledIndicator] = RECURRING_TYPE_TRANSACTIONS.include?(stored_credential[:reason_type]) ? '01' : '02' if stored_credential[:reason_type]
        post[:cardOnFile][:transactionId] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
      end

      def commit(action, parameters, option)
        url_postfix = URL_POSTFIX_MAPPING[action] || 'transactions'
        url = (test? ? "#{test_url}#{url_postfix}/#{action}" : "#{live_url}#{url_postfix}/#{action}")
        if action == 'invoice'
          response = parse(ssl_request(:delete, url, parameters.to_json, request_headers(option)))
        else
          response = parse(ssl_post(url, parameters.to_json, request_headers(option)))
        end

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 401
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def parse(body)
        return {} if body == ''

        JSON.parse(body)
      end

      def message_from(action, response)
        success_from(action, response) ? 'Transaction successful' : (error(response)&.dig('longText') || 'Transaction declined')
      end

      def error_code_from(action, response)
        return unless success_from(action, response)

        STANDARD_ERROR_CODE_MAPPING[response['primaryCode']]
      end

      def authorization_from(action, response)
        return unless success_from(action, response)

        "#{response.dig('result', 0, 'card', 'token', 'value')}|#{response.dig('result', 0, 'transaction', 'invoice')}"
      end

      def get_card_token(authorization)
        authorization.is_a?(CreditCard) ? authorization : authorization.split('|')[0]
      end

      def get_invoice(authorization)
        authorization.is_a?(CreditCard) ? authorization : authorization.split('|')[1]
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
        headers['CompanyName'] = options[:company_name]
        headers['AccessToken'] = @access_token
        headers['Invoice'] = options[:invoice] if options[:invoice].present?
        headers
      end

      def success_from(action, response)
        success = error(response).nil?
        success &&= SUCCESS_TRANSACTION_STATUS.include?(response['result'].first['transaction']['responseCode']) unless TRANSACTIONS_WITHOUT_RESPONSE_CODE.include?(action)
        success
      end

      def error(response)
        response['result'].first['error']
      end

      def current_date_time
        DateTime.now.strftime('%Y-%m-%dT%H:%M:%S.%N+%H:%M')
      end
    end
  end
end
