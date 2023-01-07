module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CommerceHubGateway < Gateway
      self.test_url = 'https://cert.api.fiservapps.com/ch'
      self.live_url = 'https://prod.api.fiservapps.com/ch'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://developer.fiserv.com/product/CommerceHub'
      self.display_name = 'CommerceHub'

      STANDARD_ERROR_CODE_MAPPING = {}

      SCHEDULED_REASON_TYPES = %w(recurring installment)
      ENDPOINTS = {
        'sale' => '/payments/v1/charges',
        'void' => '/payments/v1/cancels',
        'refund' => '/payments/v1/refunds',
        'vault' => '/payments-vas/v1/tokens'
      }

      def initialize(options = {})
        requires!(options, :api_key, :api_secret, :merchant_id, :terminal_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        options[:capture_flag] = true
        add_transaction_details(post, options)
        build_purchase_and_auth_request(post, money, payment, options)

        commit('sale', post, options)
      end

      def authorize(money, payment, options = {})
        post = {}
        options[:capture_flag] = false
        add_transaction_details(post, options)
        build_purchase_and_auth_request(post, money, payment, options)

        commit('sale', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        options[:capture_flag] = true
        add_invoice(post, money, options)
        add_transaction_details(post, options, 'capture')
        add_reference_transaction_details(post, authorization, options, 'capture')

        commit('sale', post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options) if money
        add_transaction_details(post, options)
        add_reference_transaction_details(post, authorization, options)

        commit('refund', post, options)
      end

      def void(authorization, options = {})
        post = {}
        add_transaction_details(post, options)
        add_reference_transaction_details(post, authorization, options)

        commit('void', post, options)
      end

      def store(credit_card, options = {})
        post = {}
        add_payment(post, credit_card, options)
        add_billing_address(post, credit_card, options)
        add_transaction_details(post, options)
        add_transaction_interaction(post, options)

        commit('vault', post, options)
      end

      def verify(credit_card, options = {})
        verify_amount = options[:verify_amount] || 0
        options[:primary_transaction_type] = 'AUTH_ONLY'
        options[:account_verification] = true
        authorize(verify_amount, credit_card, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: )[a-zA-Z0-9+./=]+), '\1[FILTERED]').
          gsub(%r((Api-Key: )\w+), '\1[FILTERED]').
          gsub(%r(("cardData\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("securityCode\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cavv\\?":\\?")\w+), '\1[FILTERED]')
      end

      private

      def add_transaction_interaction(post, options)
        post[:transactionInteraction] = {}
        post[:transactionInteraction][:origin] = options[:transaction_origin] || 'ECOM'
        post[:transactionInteraction][:eciIndicator] = options[:eci_indicator] || 'CHANNEL_ENCRYPTED'
        post[:transactionInteraction][:posConditionCode] = options[:pos_condition_code] || 'CARD_NOT_PRESENT_ECOM'
      end

      def add_transaction_details(post, options, action = nil)
        post[:transactionDetails] = {}
        post[:transactionDetails][:captureFlag] = options[:capture_flag] unless options[:capture_flag].nil?
        if action != 'capture'
          post[:transactionDetails][:merchantInvoiceNumber] = options[:merchant_invoice_number] || rand.to_s[2..13]
          post[:transactionDetails][:primaryTransactionType] = options[:primary_transaction_type] if options[:primary_transaction_type]
          post[:transactionDetails][:accountVerification] = options[:account_verification] unless options[:account_verification].nil?
        end
      end

      def add_billing_address(post, payment, options)
        return unless billing = options[:billing_address]

        billing_address = {}
        if payment.is_a?(CreditCard)
          billing_address[:firstName] = payment.first_name if payment.first_name
          billing_address[:lastName] = payment.last_name if payment.last_name
        end
        address = {}
        address[:street] = billing[:address1] if billing[:address1]
        address[:houseNumberOrName] = billing[:address2] if billing[:address2]
        address[:recipientNameOrAddress] = billing[:name] if billing[:name]
        address[:city] = billing[:city] if billing[:city]
        address[:stateOrProvince] = billing[:state] if billing[:state]
        address[:postalCode] = billing[:zip] if billing[:zip]
        address[:country] = billing[:country] if billing[:country]

        billing_address[:address] = address unless address.empty?
        if billing[:phone_number]
          billing_address[:phone] = {}
          billing_address[:phone][:phoneNumber] = billing[:phone_number]
        end
        post[:billingAddress] = billing_address
      end

      def add_shipping_address(post, options)
        return unless shipping = options[:shipping_address]

        shipping_address = {}
        address = {}
        address[:street] = shipping[:address1] if shipping[:address1]
        address[:houseNumberOrName] = shipping[:address2] if shipping[:address2]
        address[:recipientNameOrAddress] = shipping[:name] if shipping[:name]
        address[:city] = shipping[:city] if shipping[:city]
        address[:stateOrProvince] = shipping[:state] if shipping[:state]
        address[:postalCode] = shipping[:zip] if shipping[:zip]
        address[:country] = shipping[:country] if shipping[:country]

        shipping_address[:address] = address unless address.empty?
        if shipping[:phone_number]
          shipping_address[:phone] = {}
          shipping_address[:phone][:phoneNumber] = shipping[:phone_number]
        end
        post[:shippingAddress] = shipping_address
      end

      def build_purchase_and_auth_request(post, money, payment, options)
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_stored_credentials(post, options)
        add_transaction_interaction(post, options)
        add_billing_address(post, payment, options)
        add_shipping_address(post, options)
      end

      def add_reference_transaction_details(post, authorization, options, action = nil)
        post[:referenceTransactionDetails] = {}
        post[:referenceTransactionDetails][:referenceTransactionId] = authorization
        if action != 'capture'
          post[:referenceTransactionDetails][:referenceTransactionType] = options[:reference_transaction_type] || 'CHARGES'
          post[:referenceTransactionDetails][:referenceMerchantTransactionId] = options[:reference_merchant_transaction_id]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = {
          total: amount(money).to_f,
          currency: options[:currency] || self.default_currency
        }
      end

      def add_stored_credentials(post, options)
        return unless stored_credential = options[:stored_credential]

        post[:storedCredentials] = {}
        post[:storedCredentials][:sequence] = stored_credential[:initial_transaction] ? 'FIRST' : 'SUBSEQUENT'
        post[:storedCredentials][:initiator] = stored_credential[:initiator] == 'merchant' ? 'MERCHANT' : 'CARD_HOLDER'
        post[:storedCredentials][:scheduled] = SCHEDULED_REASON_TYPES.include?(stored_credential[:reason_type])
        post[:storedCredentials][:schemeReferenceTransactionId] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
      end

      def add_credit_card(source, payment, options)
        source[:sourceType] = 'PaymentCard'
        source[:card] = {}
        source[:card][:cardData] = payment.number
        source[:card][:expirationMonth] = format(payment.month, :two_digits) if payment.month
        source[:card][:expirationYear] = format(payment.year, :four_digits) if payment.year
        if payment.verification_value
          source[:card][:securityCode] = payment.verification_value
          source[:card][:securityCodeIndicator] = 'PROVIDED'
        end
      end

      def add_payment_token(source, payment, options)
        source[:sourceType] = 'PaymentToken'
        source[:tokenData] = payment
        source[:tokenSource] = options[:token_source] if options[:token_source]
        if options[:card_expiration_month] || options[:card_expiration_year]
          source[:card] = {}
          source[:card][:expirationMonth] = options[:card_expiration_month] if options[:card_expiration_month]
          source[:card][:expirationYear] = options[:card_expiration_year] if options[:card_expiration_year]
        end
      end

      def add_decrypted_wallet(source, payment, options)
        source[:sourceType] = 'DecryptedWallet'
        source[:card] = {}
        source[:card][:cardData] = payment.number
        source[:card][:expirationMonth] = format(payment.month, :two_digits)
        source[:card][:expirationYear] = format(payment.year, :four_digits)
        source[:cavv] = payment.payment_cryptogram
        source[:walletType] = payment.source.to_s.upcase
      end

      def add_payment(post, payment, options = {})
        source = {}
        case payment
        when NetworkTokenizationCreditCard
          add_decrypted_wallet(source, payment, options)
        when CreditCard
          add_credit_card(source, payment, options)
        when String
          add_payment_token(source, payment, options)
        end
        post[:source] = source
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(request, options)
        time = DateTime.now.strftime('%Q').to_s
        client_request_id = options[:client_request_id] || rand.to_s[2..8]
        raw_signature = @options[:api_key] + client_request_id.to_s + time + request
        hmac = OpenSSL::HMAC.digest('sha256', @options[:api_secret], raw_signature)
        signature = Base64.strict_encode64(hmac.to_s).to_s

        {
          'Client-Request-Id' => client_request_id,
          'Api-Key' => @options[:api_key],
          'Timestamp' => time,
          'Accept-Language' => 'application/json',
          'Auth-Token-Type' => 'HMAC',
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => signature
        }
      end

      def add_merchant_details(post)
        post[:merchantDetails] = {}
        post[:merchantDetails][:terminalId] = @options[:terminal_id]
        post[:merchantDetails][:merchantId] = @options[:merchant_id]
      end

      def commit(action, parameters, options)
        url = (test? ? test_url : live_url) + ENDPOINTS[action]
        add_merchant_details(parameters)
        response = parse(ssl_post(url, parameters.to_json, headers(parameters.to_json, options)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 401, 429
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(response)
        (response.dig('paymentReceipt', 'processorResponseDetails', 'responseCode') || response.dig('paymentTokens', 0, 'tokenResponseCode')) == '000'
      end

      def message_from(response)
        response.dig('paymentReceipt', 'processorResponseDetails', 'responseMessage') || response.dig('error', 0, 'message') || response.dig('gatewayResponse', 'transactionType')
      end

      def authorization_from(action, response)
        return response.dig('gatewayResponse', 'transactionProcessingDetails', 'transactionId') unless action == 'vault'
        return response.dig('paymentTokens', 0, 'tokenData') if action == 'vault'
      end

      def error_code_from(response)
        response.dig('error', 0, 'type') unless success_from(response)
      end
    end
  end
end
