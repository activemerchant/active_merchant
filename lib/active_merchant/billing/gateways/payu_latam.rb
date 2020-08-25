require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuLatamGateway < Gateway
      self.display_name = 'PayU Latam'
      self.homepage_url = 'http://www.payulatam.com'

      self.test_url = 'https://sandbox.api.payulatam.com/payments-api/4.0/service.cgi'
      self.live_url = 'https://api.payulatam.com/payments-api/4.0/service.cgi'

      self.supported_countries = %w[AR BR CL CO MX PA PE]
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master american_express diners_club naranja cabal]

      BRAND_MAP = {
        'visa' => 'VISA',
        'master' => 'MASTERCARD',
        'american_express' => 'AMEX',
        'diners_club' => 'DINERS',
        'naranja' => 'NARANJA',
        'cabal' => 'CABAL'
      }

      MINIMUMS = {
        'ARS' => 1700,
        'BRL' => 600,
        'MXN' => 3900,
        'PEN' => 500
      }

      def initialize(options={})
        requires!(options, :merchant_id, :account_id, :api_login, :api_key, :payment_country)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        auth_or_sale(post, 'AUTHORIZATION_AND_CAPTURE', amount, payment_method, options)
        commit('purchase', post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        auth_or_sale(post, 'AUTHORIZATION', amount, payment_method, options)
        commit('auth', post)
      end

      def capture(amount, authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION', options)
        add_transaction_elements(post, 'CAPTURE', options)
        add_reference(post, authorization)

        if !amount.nil? && amount.to_f != 0.0
          post[:transaction][:additionalValues] ||= {}
          post[:transaction][:additionalValues][:TX_VALUE] = invoice_for(amount, options)[:TX_VALUE]
        end

        commit('capture', post)
      end

      def void(authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION', options)
        add_transaction_elements(post, 'VOID', options)
        add_reference(post, authorization)

        commit('void', post)
      end

      def refund(amount, authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION', options)
        add_transaction_elements(post, 'REFUND', options)
        add_reference(post, authorization)

        commit('refund', post)
      end

      def verify(credit_card, options={})
        minimum = MINIMUMS[options[:currency].upcase] if options[:currency]
        amount = options[:verify_amount] || minimum || 100

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        post = {}

        add_credentials(post, 'CREATE_TOKEN')
        add_payment_method_to_be_tokenized(post, payment_method, options)

        commit('store', post)
      end

      def verify_credentials
        post = {}
        add_credentials(post, 'GET_PAYMENT_METHODS')
        response = commit('verify_credentials', post)
        response.success?
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\"creditCard\\\":{\\\"number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"securityCode\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"apiKey\\\":\\\")\w+), '\1[FILTERED]')
      end

      private

      def auth_or_sale(post, transaction_type, amount, payment_method, options)
        add_credentials(post, 'SUBMIT_TRANSACTION', options)
        add_transaction_elements(post, transaction_type, options)
        add_order(post, options)
        add_buyer(post, payment_method, options)
        add_invoice(post, amount, options)
        add_signature(post)
        add_payment_method(post, payment_method, options)
        add_payer(post, payment_method, options)
        add_extra_parameters(post, options)
      end

      def add_credentials(post, command, options={})
        post[:test] = test? unless command == 'CREATE_TOKEN'
        post[:language] = options[:language] || 'en'
        post[:command] = command
        merchant = {}
        merchant[:apiLogin] = @options[:api_login]
        merchant[:apiKey] = @options[:api_key]
        post[:merchant] = merchant
      end

      def add_transaction_elements(post, type, options)
        transaction = {}
        transaction[:paymentCountry] = @options[:payment_country]
        transaction[:type] = type
        transaction[:ipAddress] = options[:ip] || ''
        transaction[:userAgent] = options[:user_agent] if options[:user_agent]
        transaction[:cookie] = options[:cookie] if options[:cookie]
        transaction[:deviceSessionId] = options[:device_session_id] if options[:device_session_id]
        post[:transaction] = transaction
      end

      def add_order(post, options)
        order = {}
        order[:accountId] = @options[:account_id]
        order[:partnerId] = options[:partner_id] if options[:partner_id]
        order[:referenceCode] = options[:order_id] || generate_unique_id
        order[:description] = options[:description] || 'Compra en ' + @options[:merchant_id]
        order[:language] = options[:language] || 'en'
        order[:shippingAddress] = shipping_address_fields(options) if options[:shipping_address]
        post[:transaction][:order] = order
      end

      def add_payer(post, payment_method, options)
        address = options[:billing_address]
        payer = {}
        payer[:fullName] = payment_method.name.strip
        payer[:contactPhone] = address[:phone] if address && address[:phone]
        payer[:dniNumber] = options[:dni_number] if options[:dni_number]
        payer[:dniType] = options[:dni_type] if options[:dni_type]
        payer[:emailAddress] = options[:email] if options[:email]
        payer[:birthdate] = options[:birth_date] if options[:birth_date] && @options[:payment_country] == 'MX'
        payer[:billingAddress] = billing_address_fields(options)
        post[:transaction][:payer] = payer
      end

      def billing_address_fields(options)
        return unless address = options[:billing_address]

        billing_address = {}
        billing_address[:street1] = address[:address1]
        billing_address[:street2] = address[:address2]
        billing_address[:city] = address[:city]
        billing_address[:state] = address[:state]
        billing_address[:country] = address[:country] unless address[:country].blank?
        billing_address[:postalCode] = address[:zip] if @options[:payment_country] == 'MX'
        billing_address[:phone] = address[:phone]
        billing_address
      end

      def add_buyer(post, payment_method, options)
        buyer = {}
        if buyer_hash = options[:buyer]
          buyer[:fullName] = buyer_hash[:name]
          buyer[:dniNumber] = buyer_hash[:dni_number]
          buyer[:dniType] = buyer_hash[:dni_type]
          buyer[:merchantBuyerId] = buyer_hash[:merchant_buyer_id]
          buyer[:cnpj] = buyer_hash[:cnpj] if @options[:payment_country] == 'BR'
          buyer[:emailAddress] = buyer_hash[:email]
          buyer[:contactPhone] = (options[:billing_address][:phone] if options[:billing_address]) || (options[:shipping_address][:phone] if options[:shipping_address]) || ''
          buyer[:shippingAddress] = shipping_address_fields(options) if options[:shipping_address]
        else
          buyer[:fullName] = payment_method.name.strip
          buyer[:dniNumber] = options[:dni_number]
          buyer[:dniType] = options[:dni_type]
          buyer[:merchantBuyerId] = options[:merchant_buyer_id]
          buyer[:cnpj] = options[:cnpj] if @options[:payment_country] == 'BR'
          buyer[:emailAddress] = options[:email]
          buyer[:contactPhone] = (options[:billing_address][:phone] if options[:billing_address]) || (options[:shipping_address][:phone] if options[:shipping_address]) || ''
          buyer[:shippingAddress] = shipping_address_fields(options) if options[:shipping_address]
        end
        post[:transaction][:order][:buyer] = buyer
      end

      def shipping_address_fields(options)
        return unless address = options[:shipping_address]

        shipping_address = {}
        shipping_address[:street1] = address[:address1]
        shipping_address[:street2] = address[:address2]
        shipping_address[:city] = address[:city]
        shipping_address[:state] = address[:state]
        shipping_address[:country] = address[:country]
        shipping_address[:postalCode] = address[:zip]
        shipping_address[:phone] = address[:phone]
        shipping_address
      end

      def add_invoice(post, money, options)
        post[:transaction][:order][:additionalValues] = invoice_for(money, options)
      end

      def invoice_for(money, options)
        tx_value = {}
        tx_value[:value] = amount(money)
        tx_value[:currency] = options[:currency] || currency(money)

        tx_tax = {}
        tx_tax[:value] = options[:tax] || '0'
        tx_tax[:currency] = options[:currency] || currency(money)

        tx_tax_return_base = {}
        tx_tax_return_base[:value] = options[:tax_return_base] || '0'
        tx_tax_return_base[:currency] = options[:currency] || currency(money)

        additional_values = {}
        additional_values[:TX_VALUE] = tx_value
        additional_values[:TX_TAX] = tx_tax if @options[:payment_country] == 'CO'
        additional_values[:TX_TAX_RETURN_BASE] = tx_tax_return_base if @options[:payment_country] == 'CO'

        additional_values
      end

      def add_signature(post)
        post[:transaction][:order][:signature] = signature_from(post)
      end

      def signature_from(post)
        signature_string = [
          @options[:api_key],
          @options[:merchant_id],
          post[:transaction][:order][:referenceCode],
          post[:transaction][:order][:additionalValues][:TX_VALUE][:value],
          post[:transaction][:order][:additionalValues][:TX_VALUE][:currency]
        ].compact.join('~')

        Digest::MD5.hexdigest(signature_string)
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(String)
          brand, token = split_authorization(payment_method)
          credit_card = {}
          credit_card[:securityCode] = options[:cvv] if options[:cvv]
          credit_card[:processWithoutCvv2] = true if options[:cvv].blank?
          post[:transaction][:creditCard] = credit_card
          post[:transaction][:creditCardTokenId] = token
          post[:transaction][:paymentMethod] = brand.upcase
        else
          credit_card = {}
          credit_card[:number] = payment_method.number
          credit_card[:securityCode] = payment_method.verification_value || options[:cvv]
          credit_card[:expirationDate] = format(payment_method.year, :four_digits).to_s + '/' + format(payment_method.month, :two_digits).to_s
          credit_card[:name] = payment_method.name.strip
          credit_card[:processWithoutCvv2] = true if add_process_without_cvv2(payment_method, options)
          post[:transaction][:creditCard] = credit_card
          post[:transaction][:paymentMethod] = BRAND_MAP[payment_method.brand.to_s]
        end
      end

      def add_process_without_cvv2(payment_method, options)
        return true if payment_method.verification_value.blank? && options[:cvv].blank?

        false
      end

      def add_extra_parameters(post, options)
        extra_parameters = {}
        extra_parameters[:INSTALLMENTS_NUMBER] = options[:installments_number] || 1
        post[:transaction][:extraParameters] = extra_parameters
      end

      def add_reference(post, authorization)
        order_id, transaction_id = split_authorization(authorization)
        order = {}
        order[:id] = order_id
        post[:transaction][:order] = order
        post[:transaction][:parentTransactionId] = transaction_id
        post[:transaction][:reason] = 'n/a'
      end

      def add_payment_method_to_be_tokenized(post, payment_method, options)
        credit_card_token = {}
        credit_card_token[:payerId] = options[:payer_id] || generate_unique_id
        credit_card_token[:name] = payment_method.name.strip
        credit_card_token[:identificationNumber] = options[:dni_number]
        credit_card_token[:paymentMethod] = BRAND_MAP[payment_method.brand.to_s]
        credit_card_token[:number] = payment_method.number
        credit_card_token[:expirationDate] = format(payment_method.year, :four_digits).to_s + '/' + format(payment_method.month, :two_digits).to_s
        post[:creditCardToken] = credit_card_token
      end

      def commit(action, params)
        raw_response = ssl_post(url, post_data(params), headers)
        response = parse(raw_response)
      rescue ResponseError => e
        raw_response = e.response.body
        response_error(raw_response)
      rescue JSON::ParserError
        unparsable_response(raw_response)
      else
        success = success_from(action, response)
        Response.new(
          success,
          message_from(action, success, response),
          response,
          authorization: success ? authorization_from(action, response) : nil,
          error_code: success ? nil : error_from(action, response),
          test: test?
        )
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      end

      def post_data(params)
        params.merge(test: test?)
        params.to_json
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(action, response)
        case action
        when 'store'
          response['code'] == 'SUCCESS' && response['creditCardToken'] && response['creditCardToken']['creditCardTokenId'].present?
        when 'verify_credentials'
          response['code'] == 'SUCCESS'
        when 'refund', 'void'
          response['code'] == 'SUCCESS' && response['transactionResponse'] && (response['transactionResponse']['state'] == 'PENDING' || response['transactionResponse']['state'] == 'APPROVED')
        else
          response['code'] == 'SUCCESS' && response['transactionResponse'] && (response['transactionResponse']['state'] == 'APPROVED')
        end
      end

      def message_from(action, success, response)
        case action
        when 'store'
          return response['code'] if success

          error_description = response['creditCardToken']['errorDescription'] if response['creditCardToken']
          response['error'] || error_description || 'FAILED'
        when 'verify_credentials'
          return 'VERIFIED' if success

          'FAILED'
        else
          if response['transactionResponse']
            response_message = response['transactionResponse']['responseMessage']

            response_code = response['transactionResponse']['responseCode'] || response['transactionResponse']['pendingReason']

            response_message = response_code + ' | ' + response['transactionResponse']['paymentNetworkResponseErrorMessage'] unless response['transactionResponse']['paymentNetworkResponseErrorMessage'].nil?
          end
          return response_code if success

          response_message || response['error'] || response_code || 'FAILED'
        end
      end

      def authorization_from(action, response)
        case action
        when 'store'
          [
            response['creditCardToken']['paymentMethod'],
            response['creditCardToken']['creditCardTokenId']
          ].compact.join('|')
        when 'verify_credentials'
          nil
        else
          [
            response['transactionResponse']['orderId'],
            response['transactionResponse']['transactionId']
          ].compact.join('|')
        end
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def error_from(action, response)
        case action
        when 'store'
          response['creditCardToken']['errorDescription'] if response['creditCardToken']
        when 'verify_credentials'
          response['error'] || 'FAILED'
        else
          response['transactionResponse']['errorCode'] || response['transactionResponse']['responseCode'] if response['transactionResponse']
        end
      end

      def response_error(raw_response)
        response = parse(raw_response)
      rescue JSON::ParserError
        unparsable_response(raw_response)
      else
        return Response.new(
          false,
          message_from('', false, response),
          response,
          test: test?
        )
      end

      def unparsable_response(raw_response)
        message = 'Invalid JSON response received from PayuLatamGateway. Please contact PayuLatamGateway if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
