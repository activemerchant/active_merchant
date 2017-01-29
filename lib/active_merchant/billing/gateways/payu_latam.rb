require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuLatamGateway < Gateway
      self.display_name = "PayU Latam"
      self.homepage_url = "http://www.payulatam.com"

      self.test_url = "https://sandbox.api.payulatam.com/payments-api/4.0/service.cgi"
      self.live_url = "https://api.payulatam.com/payments-api/4.0/service.cgi"

      self.supported_countries = ["AR", "BR", "CL", "CO", "MX", "PA", "PE"]
      self.default_currency = "USD"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      BRAND_MAP = {
        "visa" => "VISA",
        "master" => "MASTERCARD",
        "american_express" => "AMEX",
        "diners_club" => "DINERS"
      }

      MINIMUMS = {
        "ARS" => 1700,
        "BRL" => 600,
        "MXN" => 3900,
        "PEN" => 500
      }

      def initialize(options={})
        requires!(options, :merchant_id, :account_id, :api_login, :api_key)
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

      def capture(authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION')
        add_transaction_type(post, 'CAPTURE')
        add_reference(post, authorization)

        commit('capture', post)
      end

      def void(authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION')
        add_transaction_type(post, 'VOID')
        add_reference(post, authorization)

        commit('void', post)
      end

      def refund(authorization, options={})
        post = {}

        add_credentials(post, 'SUBMIT_TRANSACTION')
        add_transaction_type(post, 'REFUND')
        add_reference(post, authorization)

        commit('refund', post)
      end

      def verify(credit_card, options={})
        minimum = MINIMUMS[options[:currency].upcase] if options[:currency]
        amount = minimum || 100

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        post = {}

        add_credentials(post, 'CREATE_TOKEN')
        add_payment_method_to_be_tokenized(post, payment_method)

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
        add_credentials(post, 'SUBMIT_TRANSACTION')
        add_transaction_type(post, transaction_type)
        add_order(post, options)
        add_buyer(post, options)
        add_invoice(post, amount, options)
        add_signature(post)
        add_payment_method(post, payment_method, options)
        add_payer(post, options)
        add_extra_parameters(post, options)
      end

      def add_credentials(post, command)
        post[:test] = test? unless command == 'CREATE_TOKEN'
        post[:language] = 'en'
        post[:command] = command
        merchant = {}
        merchant[:apiLogin] = @options[:api_login]
        merchant[:apiKey] = @options[:api_key]
        post[:merchant] = merchant
      end

      def add_transaction_type(post, type)
        transaction = {}
        transaction[:type] = type
        post[:transaction] = transaction
      end

      def add_order(post, options)
        order = {}
        order[:accountId] = @options[:account_id]
        order[:referenceCode] = options[:order_id] || generate_unique_id
        order[:description] = options[:description] || 'unspecified'
        order[:language] = 'en'
        post[:transaction][:order] = order
      end

      def add_buyer(post, options)
        if address = options[:shipping_address]
          buyer = {}
          buyer[:fullName] = address[:name]
          shipping_address = {}
          shipping_address[:street1] = address[:address1]
          shipping_address[:street2] = address[:address2]
          shipping_address[:city] = address[:city]
          shipping_address[:state] = address[:state]
          shipping_address[:country] = address[:country]
          shipping_address[:postalCode] = address[:zip]
          shipping_address[:phone] = address[:phone]
          buyer[:shippingAddress] = shipping_address
          post[:transaction][:order][:buyer] = buyer
        end
      end

      def add_invoice(post, money, options)
        tx_value = {}
        tx_value[:value] = amount(money)
        tx_value[:currency] = options[:currency] || currency(money)

        additional_values = {}
        additional_values[:TX_VALUE] = tx_value

        post[:transaction][:order][:additionalValues] = additional_values
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
        ].compact.join("~")

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
          credit_card[:securityCode] = add_security_code(payment_method, options)
          credit_card[:expirationDate] = format(payment_method.year, :four_digits).to_s + '/' + format(payment_method.month, :two_digits).to_s
          credit_card[:name] = payment_method.name.strip
          credit_card[:processWithoutCvv2] = true if add_process_without_cvv2(payment_method, options)
          post[:transaction][:creditCard] = credit_card
          post[:transaction][:paymentMethod] = BRAND_MAP[payment_method.brand.to_s]
        end
      end

      def add_security_code(payment_method, options)
        return payment_method.verification_value unless payment_method.verification_value.blank?
        return options[:cvv] unless options[:cvv].blank?
        return "0000" if BRAND_MAP[payment_method.brand.to_s] == "AMEX"
        "000"
      end

      def add_process_without_cvv2(payment_method, options)
        return true if payment_method.verification_value.blank? && options[:cvv].blank?
        false
      end

      def add_payer(post, options)
        if address = options[:billing_address]
          payer = {}
          post[:transaction][:paymentCountry] = address[:country]
          payer[:fullName] = address[:name]
          payer[:contactPhone] = address[:phone]
          billing_address = {}
          billing_address[:street1] = address[:address1]
          billing_address[:street2] = address[:address2]
          billing_address[:city] = address[:city]
          billing_address[:state] = address[:state]
          billing_address[:country] = address[:country]
          billing_address[:postalCode] = address[:zip]
          billing_address[:phone] = address[:phone]
          payer[:billingAddress] = billing_address
          post[:transaction][:payer] = payer
        end
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

      def add_payment_method_to_be_tokenized(post, payment_method)
        credit_card_token = {}
        credit_card_token[:payerId] = generate_unique_id
        credit_card_token[:name] = payment_method.name.strip
        credit_card_token[:identificationNumber] = generate_unique_id
        credit_card_token[:paymentMethod] = BRAND_MAP[payment_method.brand.to_s]
        credit_card_token[:number] = payment_method.number
        credit_card_token[:expirationDate] = format(payment_method.year, :four_digits).to_s + '/' + format(payment_method.month, :two_digits).to_s
        credit_card_token[:securityCode] = payment_method.verification_value
        post[:creditCardToken] = credit_card_token
      end

      def commit(action, params)
        begin
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
      end

      def headers
        {
          "Content-Type"  => "application/json",
          "Accept"  => "application/json"
        }
      end

      def post_data(params)
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
          response["code"] == "SUCCESS" && response["creditCardToken"] && response["creditCardToken"]["creditCardTokenId"].present?
        when 'verify_credentials'
          response["code"] == "SUCCESS"
        else
          response["code"] == "SUCCESS" && response["transactionResponse"] && (response["transactionResponse"]["state"] == "APPROVED")
        end
      end

      def message_from(action, success, response)
        case action
        when 'store'
          return response["code"] if success
          error_description = response["creditCardToken"]["errorDescription"] if response["creditCardToken"]
          response["error"] || error_description || "FAILED"
        when 'verify_credentials'
          return "VERIFIED" if success
          "FAILED"
        else
          response_message = response["transactionResponse"]["responseMessage"] if response["transactionResponse"]
          response_code = response["transactionResponse"]["responseCode"] if response["transactionResponse"]
          return response_code if success
          response["error"] || response_message || response_code || "FAILED"
        end
      end

      def authorization_from(action, response)
        case action
        when 'store'
          [
            response["creditCardToken"]["paymentMethod"],
            response["creditCardToken"]["creditCardTokenId"]
          ].compact.join("|")
        when 'verify_credentials'
          nil
        else
          [
            response["transactionResponse"]["orderId"],
            response["transactionResponse"]["transactionId"]
          ].compact.join("|")
        end
      end

      def split_authorization(authorization)
        authorization.split("|")
      end

      def error_from(action, response)
        case action
        when 'store'
          response["creditCardToken"]["errorDescription"] if response["creditCardToken"]
        when 'verify_credentials'
          response["error"] || "FAILED"
        else
          response["transactionResponse"]["errorCode"] || response["transactionResponse"]["responseCode"] if response["transactionResponse"]
        end
      end

      def response_error(raw_response)
        begin
          response = parse(raw_response)
        rescue JSON::ParserError
          unparsable_response(raw_response)
        else
          return Response.new(
            false,
            message_from('', false, response),
            response,
            :test => test?
          )
        end
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from PayuLatamGateway. Please contact PayuLatamGateway if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
