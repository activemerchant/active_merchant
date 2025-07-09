module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class Shift4Gateway < Gateway
      version 'v1'

      self.test_url = "https://utgapi.shift4test.com/api/rest/#{fetch_version}/"
      self.live_url = "https://utg.shift4api.net/api/rest/#{fetch_version}/"

      self.supported_countries = %w(US CA CU HT DO PR JM TT GP MQ BS BB LC CW AW VC VI GD AG DM KY KN SX TC MF VG BQ AI BL MS)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://shift4.com'
      self.display_name = 'Shift4'

      RECURRING_TYPE_TRANSACTIONS = %w(recurring installment)
      TRANSACTIONS_WITHOUT_RESPONSE_CODE = %w(accesstoken add)
      SUCCESS_TRANSACTION_STATUS = %w(A)
      DISALLOWED_ENTRY_MODE_ACTIONS = %w(capture refund add verify)
      URL_POSTFIX_MAPPING = {
        'accesstoken' => 'credentials',
        'add' => 'tokens',
        'verify' => 'cards'
      }

      def initialize(options = {})
        requires!(options, :client_guid, :auth_token)
        @client_guid = options[:client_guid]
        @auth_token = options[:auth_token]
        @access_token = options[:access_token]
        super
      end

      def purchase(money, payment_method, options = {})
        post = {}
        action = 'sale'

        payment_method = get_card_token(payment_method) if payment_method.is_a?(String)
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(action, post, payment_method, options)
        add_card_present(post, options)
        add_customer(post, payment_method, options)

        commit(action, post, options)
      end

      def authorize(money, payment_method, options = {})
        post = {}
        action = 'authorization'

        payment_method = get_card_token(payment_method) if payment_method.is_a?(String)
        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(action, post, payment_method, options)
        add_card_present(post, options)
        add_customer(post, payment_method, options)

        commit(action, post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        action = 'capture'
        options[:invoice] = get_invoice(authorization)

        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        add_card(action, post, get_card_token(authorization), options)

        commit(action, post, options)
      end

      def refund(money, payment_method, options = {})
        post = {}
        action = 'refund'

        add_datetime(post, options)
        add_invoice(post, money, options)
        add_clerk(post, options)
        add_transaction(post, options)
        card_token = payment_method.is_a?(CreditCard) ? get_card_token(payment_method) : payment_method
        add_card(action, post, card_token, options)
        add_card_present(post, options)

        commit(action, post, options)
      end

      alias credit refund

      def void(authorization, options = {})
        options[:invoice] = get_invoice(authorization)
        commit('invoice', {}, options)
      end

      def verify(credit_card, options = {})
        post = {}
        action = 'verify'
        post[:transaction] = {}

        add_datetime(post, options)
        add_card(action, post, credit_card, options)
        add_customer(post, credit_card, options)
        add_card_on_file(post[:transaction], options)

        commit(action, post, options)
      end

      def store(credit_card, options = {})
        post = {}
        action = 'add'

        add_datetime(post, options)
        add_card(action, post, credit_card, options)
        add_customer(post, credit_card, options)

        commit(action, post, options)
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
          gsub(%r(("securityCode\\?":{\\?"\w+\\?":\d+,\\?"value\\?":\\?")\d*)i, '\1[FILTERED]')
      end

      def setup_access_token
        post = {}
        add_credentials(post, options)
        add_datetime(post, options)

        response = commit('accesstoken', post, request_headers('accesstoken', options))
        raise OAuthResponseError.new(response, response.params.fetch('result', [{}]).first.dig('error', 'longText')) unless response.success?

        response.params['result'].first['credential']['accessToken']
      end

      private

      def add_credentials(post, options)
        post[:credential] = {}
        post[:credential][:clientGuid] = @client_guid
        post[:credential][:authToken] = @auth_token
      end

      def add_clerk(post, options)
        post[:clerk] = {}
        post[:clerk][:numericId] = options[:clerk_id] || '1'
      end

      def add_invoice(post, money, options)
        post[:amount] = {}
        post[:amount][:total] = amount(money.to_f)
        post[:amount][:tax] = options[:tax].to_f || 0.0
      end

      def add_datetime(post, options)
        post[:dateTime] = options[:date_time] || current_date_time(options)
      end

      def add_transaction(post, options)
        post[:transaction] = {}
        post[:transaction][:invoice] = options[:invoice] || (Time.new.to_i.to_s[1..3] + rand.to_s[2..7])
        post[:transaction][:notes] = options[:notes] if options[:notes].present?
        post[:transaction][:vendorReference] = options[:order_id]

        add_purchase_card(post[:transaction], options)
        add_card_on_file(post[:transaction], options)
      end

      def add_card(action, post, payment_method, options)
        post[:card] = {}
        post[:card][:entryMode] = options[:entry_mode] || 'M' unless DISALLOWED_ENTRY_MODE_ACTIONS.include?(action)
        if payment_method.is_a?(CreditCard)
          post[:card][:expirationDate] = "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
          post[:card][:number] = payment_method.number
          post[:card][:securityCode] = {}
          post[:card][:securityCode][:indicator] = 1
          post[:card][:securityCode][:value] = payment_method.verification_value
        else
          post[:card] = {} if post[:card].nil?
          post[:card][:token] = {}
          post[:card][:token][:value] = payment_method
          post[:card][:expirationDate] = options[:expiration_date] if options[:expiration_date]
        end
      end

      def add_card_present(post, options)
        post[:card] = {} unless post[:card].present?

        post[:card][:present] = options[:card_present] || 'N'
      end

      def add_customer(post, card, options)
        address = options[:billing_address] || {}

        post[:customer] = {}
        post[:customer][:addressLine1] = address[:address1] if address[:address1]
        post[:customer][:postalCode] = address[:zip] if address[:zip] && !address[:zip]&.to_s&.empty?
        post[:customer][:firstName] = card.first_name if card.is_a?(CreditCard) && card.first_name
        post[:customer][:lastName] = card.last_name if card.is_a?(CreditCard) && card.last_name
        post[:customer][:emailAddress] = options[:email] if options[:email]
        post[:customer][:ipAddress] = options[:ip] if options[:ip]
      end

      def add_purchase_card(post, options)
        return unless options[:customer_reference] || options[:destination_postal_code] || options[:product_descriptors]

        post[:purchaseCard] = {}
        post[:purchaseCard][:customerReference] = options[:customer_reference] if options[:customer_reference]
        post[:purchaseCard][:destinationPostalCode] = options[:destination_postal_code] if options[:destination_postal_code]
        post[:purchaseCard][:productDescriptors] = options[:product_descriptors] if options[:product_descriptors]
      end

      def add_card_on_file(post, options)
        return unless options[:stored_credential] || options[:usage_indicator] || options[:indicator] || options[:scheduled_indicator] || options[:transaction_id]

        stored_credential = options[:stored_credential] || {}
        post[:cardOnFile] = {}
        post[:cardOnFile][:usageIndicator] = options[:usage_indicator] || (stored_credential[:initial_transaction] ? '01' : '02')
        post[:cardOnFile][:indicator] = options[:indicator] || '01'
        post[:cardOnFile][:scheduledIndicator] = options[:scheduled_indicator] || (RECURRING_TYPE_TRANSACTIONS.include?(stored_credential[:reason_type]) ? '01' : '02')
        post[:cardOnFile][:transactionId] = options[:transaction_id] || stored_credential[:network_transaction_id] if options[:transaction_id] || stored_credential[:network_transaction_id]
      end

      def commit(action, parameters, option)
        url_postfix = URL_POSTFIX_MAPPING[action] || 'transactions'
        url = (test? ? "#{test_url}#{url_postfix}/#{action}" : "#{live_url}#{url_postfix}/#{action}")
        if action == 'invoice'
          response = parse(ssl_request(:delete, url, parameters.to_json, request_headers(action, option)))
        else
          response = parse(ssl_post(url, parameters.to_json, request_headers(action, option)))
        end

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          avs_result: avs_result_from(response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 401, 500
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
        if success_from(action, response)
          'Transaction successful'
        else
          error(response)&.dig('longText') ||
            response['result'].first&.dig('transaction', 'hostresponse', 'reasonDescription') ||
            response['result'].first&.dig('transaction', 'hostResponse', 'reasonDescription') ||
            'Transaction declined'
        end
      end

      def error_code_from(action, response)
        code = response['result'].first&.dig('transaction', 'responseCode')
        primary_code = response['result'].first['error'].present?
        return unless code == 'D' || primary_code == true || success_from(action, response)

        if response['result'].first&.dig('transaction', 'hostresponse')
          response['result'].first&.dig('transaction', 'hostresponse', 'reasonCode')
        elsif response['result'].first&.dig('transaction', 'hostResponse')
          response['result'].first&.dig('transaction', 'hostResponse', 'reasonCode')
        elsif response['result'].first['error']
          response['result'].first&.dig('error', 'primaryCode')
        else
          response['result'].first&.dig('transaction', 'responseCode')
        end
      end

      def avs_result_from(response)
        AVSResult.new(code: response['result'].first&.dig('transaction', 'avs', 'result')) if response['result'].first&.dig('transaction', 'avs')
      end

      def authorization_from(action, response)
        return unless success_from(action, response)

        authorization = response.dig('result', 0, 'card', 'token', 'value').to_s
        invoice = response.dig('result', 0, 'transaction', 'invoice')
        authorization += "|#{invoice}" if invoice
        authorization
      end

      def get_card_token(authorization)
        authorization.is_a?(CreditCard) ? authorization : authorization.split('|')[0]
      end

      def get_invoice(authorization)
        authorization.is_a?(CreditCard) ? authorization : authorization.split('|')[1]
      end

      def request_headers(action, options)
        headers = {
          'Content-Type' => 'application/json'
        }
        headers['AccessToken'] = @access_token
        headers['Invoice'] = options[:invoice] if action != 'capture' && options[:invoice].present?
        headers['InterfaceVersion'] = '1'
        headers['InterfaceName'] = options[:interface_name]
        headers['CompanyName'] = 'Spreedly'
        headers
      end

      def success_from(action, response)
        success = error(response).nil?
        success &&= SUCCESS_TRANSACTION_STATUS.include?(response['result'].first['transaction']['responseCode']) unless TRANSACTIONS_WITHOUT_RESPONSE_CODE.include?(action)
        success
      end

      def error(response)
        server_error = { 'longText' => response['error'] } if response['error']
        server_error || response['result'].first['error']
      end

      def current_date_time(options = {})
        time_zone = options[:merchant_time_zone] || 'Pacific Time (US & Canada)'
        time = Time.now.in_time_zone(time_zone)
        offset = Time.now.in_time_zone(time_zone).formatted_offset

        time.strftime('%Y-%m-%dT%H:%M:%S.%3N') + offset
      end
    end
  end
end
