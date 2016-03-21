module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VisanetPeruGateway < Gateway
      self.display_name = "VisaNet Peru Gateway"
      self.homepage_url = "http://www.visanet.com.pe"

      self.test_url = "https://devapi.vnforapps.com/api.tokenization/api/v2/merchant"
      self.live_url = "https://api.vnforapps.com/api.tokenization/api/v2/merchant"

      self.supported_countries = ["US", "PE"]
      self.default_currency = "PEN"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :access_key_id, :secret_access_key)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run() do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(r.authorization, options) }
        end
      end

      def authorize(amount, payment_method, options={})
        #JSON
        post = {}

        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_device_fingerprint_data(post, options)
        add_merchant_define_data(post, options)

        # No vaulting for now
        post[:createAlias] = false

        commit("authorize", post, options)
      end

      def capture(authorization, options={})
        params = {}
        action, merchant_id, purchase_number = split_authorization(authorization)
        options[:merchant_id] = merchant_id
        options[:purchaseNumber] = purchase_number
        params[:externalTransactionId] = purchase_number
        commit("capture", params, options)
      end

      def void(authorization, options={})
        params = {}
        action, merchant_id, purchase_number = split_authorization(authorization)
        options[:merchant_id] = merchant_id
        options[:purchaseNumber] = purchase_number
        params[:externalTransactionId] = purchase_number
        puts options
        case action
        when "authorize"
          commit("void", params, options)
        when "capture"
          commit("cancel", params, options)
        end
      end

      # def refund(amount, authorization, options={})
      # end

      # def credit(amount, payment_method, options={})
      # end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # def store(payment_method, options = {})
      #   post = {}
      #   add_payment_method(post, payment_method)
      #   add_customer_data(post, options)

      #   commit("store", post)
      # end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        #JSON.
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((\"cardNumber\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"cvv2Code\\\":)\d+), '\1[FILTERED]')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = 840
      CURRENCY_CODES["PEN"] = 604

      def add_invoice(post, money, options)
        post[:amount] = amount(money).to_f
        # Visanet Peru expects a 9-digit numeric purchaseNumber
        post[:purchaseNumber] = options[:order_id]
        post[:externalTransactionId] = options[:order_id]
        post[:currencyId] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_payment_method(post, payment_method)
        post[:firstName] = payment_method.first_name
        post[:lastName] = payment_method.last_name
        post[:cardNumber] = payment_method.number
        post[:cvv2Code] = Integer(payment_method.verification_value, 10)
        post[:expirationYear] = format(payment_method.year, :four_digits)
        post[:expirationMonth] = format(payment_method.month, :two_digits)
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        antifraud = {}
        billing_address = options[:billing_address] || options[:address]
        if (billing_address)
          antifraud[:billTo_street1] = billing_address[:address1]
          antifraud[:billTo_city] = billing_address[:city]
          antifraud[:billTo_state] = billing_address[:state]
          antifraud[:billTo_country] = billing_address[:country]
          antifraud[:billTo_postalCode]    = billing_address[:zip]
        end
        post[:antifraud] = antifraud
      end

      def add_device_fingerprint_data(post, options)
        post[:antifraud][:deviceFingerprintId] = options[:device_fingerprint_id]
      end

      def add_merchant_define_data(post, options)
        if (merchantDefineData = options[:merchant_define_data])
          post[:antifraud][:merchantDefineData] = merchantDefineData
        end
      end

      def commit(action, params, options)
        case action
        when "authorize"
          url = base_url() + "/" + options[:merchant_id]
          method = :post
        when "capture"
          url = base_url() + "/" + options[:merchant_id] + "/deposit/" + options[:purchaseNumber]
          method = :put
        when "void"
          url = base_url() + "/" + options[:merchant_id] + "/void/" + options[:purchaseNumber]
          method = :put
        when "cancel"
          url = base_url() + "/" + options[:merchant_id] + "/cancelDeposit/" + options[:purchaseNumber]
          method = :put
        end
        begin
          raw_response = ssl_request(method, url, post_data(action, params), headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response_error(raw_response)
        rescue JSON::ParserError
          unparsable_response(raw_response)
        else
          Response.new(
            success_from(response),
            message_from(response),
            response,
            :test => test?,
            :authorization => action + "|" + (response["merchantId"] || '') + "|" + (response["externalTransactionId"] || ''),
            :error_code => response["errorCode"]
          )
        end
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64("#{@options[:access_key_id]}:#{@options[:secret_access_key]}").strip,
          "Content-Type"  => "application/json"
        }
      end

      def split_authorization(authorization)
        authorization.split("|")
      end

      def post_data(action, params)
        # JSON.
        params.to_json
      end

      def base_url
        test? ? test_url : live_url
      end

      def parse(body)
        # JSON.
        JSON.parse(body)
      end

      def success_from(response)
        response["errorCode"] == 0
      end

      def message_from(response)
        response["errorMessage"]
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
