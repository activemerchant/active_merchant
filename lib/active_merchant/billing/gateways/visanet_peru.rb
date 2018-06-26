module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VisanetPeruGateway < Gateway
      include Empty
      self.display_name = 'VisaNet Peru Gateway'
      self.homepage_url = 'http://www.visanet.com.pe'

      self.test_url = 'https://devapi.vnforapps.com/api.tokenization/api/v2/merchant'
      self.live_url = 'https://api.vnforapps.com/api.tokenization/api/v2/merchant'

      self.supported_countries = ['US', 'PE']
      self.default_currency = 'PEN'
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

        commit('authorize', params, options)
      end

      def capture(authorization, options={})
        params = {}
        options[:id_unico] = split_authorization(authorization)[1]
        add_auth_order_id(params, authorization, options)
        commit('deposit', params, options)
      end

      def void(authorization, options={})
        params = {}
        add_auth_order_id(params, authorization, options)
        commit('void', params, options)
      end

      def refund(amount, authorization, options={})
        params = {}
        params[:amount] = amount(amount) if amount
        add_auth_order_id(params, authorization, options)
        response = commit('cancelDeposit', params, options)
        return response if response.success? || split_authorization(authorization).length == 1 || !options[:force_full_refund_if_unsettled]

        # Attempt RefundSingleTransaction if unsettled
        prepare_refund_data(params, authorization, options)
        commit('refund', params, options)
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
      CURRENCY_CODES['USD'] = 840
      CURRENCY_CODES['PEN'] = 604

      def add_invoice(params, money, options)
        # Visanet Peru expects a 9-digit numeric purchaseNumber
        params[:purchaseNumber] = (SecureRandom.random_number(900_000_000) + 100_000_000).to_s
        params[:externalTransactionId] = options[:order_id]
        params[:amount] = amount(money)
        params[:currencyId] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_auth_order_id(params, authorization, options)
        purchase_number, _ = split_authorization(authorization)
        params[:purchaseNumber] = purchase_number
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

      def commit(action, params, options={})
        begin
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
            :test => test?,
            :authorization => authorization_from(params, response, options),
            :error_code => response['errorCode']
          )
        end
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:access_key_id]}:#{@options[:secret_access_key]}").strip,
          'Content-Type'  => 'application/json'
        }
      end

      def url(action, params, options={})
        if (action == 'authorize')
          "#{base_url}/#{@options[:merchant_id]}"
        elsif (action == 'refund')
          "#{base_url}/#{@options[:merchant_id]}/#{action}/#{options[:transaction_id]}"
        else
          "#{base_url}/#{@options[:merchant_id]}/#{action}/#{params[:purchaseNumber]}"
        end
      end

      def method(action)
        (%w(authorize refund).include? action) ? :post : :put
      end

      def authorization_from(params, response, options)
        id_unico = response['data']['ID_UNICO'] || options[:id_unico]
        "#{params[:purchaseNumber]}|#{id_unico}"
      end

      def base_url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response['errorCode'] == 0
      end

      def message_from(response, options, action)
        if empty?(response['errorMessage']) || response['errorMessage'] == '[ ]'
          action == 'refund' ? "#{response['data']['DSC_COD_ACCION']}, #{options[:error_message]}" : response['data']['DSC_COD_ACCION']
        elsif action == 'refund'
          message = "#{response['errorMessage']}, #{options[:error_message]}"
          options[:error_message] = response['errorMessage']
          message
        else
          response['errorMessage']
        end
      end

      def response_error(raw_response, options, action)
        begin
          response = parse(raw_response)
        rescue JSON::ParserError
          unparsable_response(raw_response)
        else
          return Response.new(
            false,
            message_from(response, options, action),
            response,
            :test => test?,
            :authorization => response['transactionUUID'],
            :error_code => response['errorCode']
          )
        end
      end

      def unparsable_response(raw_response)
        message = 'Invalid JSON response received from VisanetPeruGateway. Please contact VisanetPeruGateway if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
