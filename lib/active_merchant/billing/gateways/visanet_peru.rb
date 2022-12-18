module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VisanetPeruGateway < Gateway
      include Empty
      self.display_name = "VisaNet Peru Gateway"
      self.homepage_url = "http://www.visanet.com.pe"

      self.test_url = "https://devapi.vnforapps.com/api.tokenization/api/v2/merchant"
      self.live_url = "https://api.vnforapps.com/api.tokenization/api/v2/merchant"

      self.supported_countries = ["US", "PE"]
      self.default_currency = "PEN"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :access_key_id, :secret_access_key, :merchant_id)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run() do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(r.authorization, options) }
        end
      end

      def authorize(amount, payment_method, options={})
        params = {}

        add_invoice(params, amount, options)
        add_payment_method(params, payment_method)
        add_antifraud_data(params, options)
        params[:email] = options[:email] || 'unknown@email.com'
        params[:createAlias] = false

        commit("authorize", params)
      end

      def capture(authorization, options={})
        params = {}
        add_auth_order_id(params, authorization, options)
        commit("deposit", params)
      end

      def void(authorization, options={})
        params = {}
        add_auth_order_id(params, authorization, options)
        commit("void", params)
      end

      def refund(amount, authorization, options={})
        params = {}
        add_auth_order_id(params, authorization, options)
        commit("cancelDeposit", params)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((\"cardNumber\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"cvv2Code\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = 840
      CURRENCY_CODES["PEN"] = 604

      def add_invoice(params, money, options)
        # Visanet Peru expects a 12-digit alphanumeric purchaseNumber
        params[:purchaseNumber] = generate_purchase_number_stamp
        params[:externalTransactionId] = options[:order_id]
        params[:amount] = amount(money)
        params[:currencyId] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_auth_order_id(params, authorization, options)
        params[:purchaseNumber] = authorization
        params[:externalTransactionId] = options[:order_id]
      end

      def add_payment_method(params, payment_method)
        params[:firstName] = payment_method.first_name
        params[:lastName] = payment_method.last_name
        params[:cardNumber] = payment_method.number
        params[:cvv2Code] = payment_method.verification_value
        params[:expirationYear] = format(payment_method.year, :four_digits)
        params[:expirationMonth] = format(payment_method.month, :two_digits)
      end

      def add_antifraud_data(params, options)
        antifraud = {}

        if billing_address = options[:billing_address] || options[:address]
          antifraud[:billTo_street1] = billing_address[:address1]
          antifraud[:billTo_city] = billing_address[:city]
          antifraud[:billTo_state] = billing_address[:state]
          antifraud[:billTo_country] = billing_address[:country]
          antifraud[:billTo_postalCode] = billing_address[:zip]
        end

        antifraud[:deviceFingerprintId] = options[:device_fingerprint_id] || SecureRandom.hex(16)
        antifraud[:merchantDefineData] = options[:merchant_define_data] if options[:merchant_define_data]

        params[:antifraud] = antifraud
      end

      def prepare_refund_data(params, authorization, options)
        params.delete(:purchaseNumber)
        params[:externalReferenceId] = params.delete(:externalTransactionId)
        _, transaction_id = split_authorization(authorization)

        options.update(transaction_id: transaction_id)
        params[:ruc] = options[:ruc]
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def generate_purchase_number_stamp
        Time.now.to_f.to_s.delete('.')[1..10] + rand(99).to_s
      end

      def commit(action, params, options = {})
        raw_response = ssl_request(method(action), url(action, params, options), params.to_json, headers)
        response = parse(raw_response)
      rescue ResponseError => e
        raw_response = e.response.body
        response_error(raw_response, options, action)
      rescue JSON::ParserError
        unparsable_response(raw_response)
      else
        Response.new(
          success_from(response),
          message_from(response, options, action),
          response,
          test: test?,
          authorization: authorization_from(params, response, options),
          error_code: response['errorCode']
        )
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64("#{@options[:access_key_id]}:#{@options[:secret_access_key]}").strip,
          "Content-Type"  => "application/json"
        }
      end

      def url(action, params)
        if (action == "authorize")
          "#{base_url}/#{@options[:merchant_id]}"
        else
          "#{base_url}/#{@options[:merchant_id]}/#{action}/#{params[:purchaseNumber]}"
        end
      end

      def method(action)
        (action == "authorize") ? :post : :put
      end

      def authorization_from(params)
        params[:purchaseNumber]
      end

      def base_url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response["errorCode"] == 0
      end

      def message_from(response)
        if empty?(response["errorMessage"]) || response["errorMessage"] == "[ ]"
          response["data"]["DSC_COD_ACCION"]
        else
          response["errorMessage"]
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
            message_from(response),
            response,
            :test => test?,
            :authorization => response["transactionUUID"],
            :error_code => response["errorCode"]
          )
        end
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from VisanetPeruGateway. Please contact VisanetPeruGateway if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
