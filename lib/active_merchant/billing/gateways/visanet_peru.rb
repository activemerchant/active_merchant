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
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run(:use_first_response) do |r|
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
        add_merchant_define_data(post, options)

        # No vaulting for now
        post[:createAlias] = false

        commit("authorize", post, options)
      end

      def capture(authorization, options={})
        options[:purchaseNumber] = authorization
        commit("capture", options)
      end

      # void revokes previous authorize operation
      def void(authorization, options={})
        options[:purchaseNumber] = authorization
        commit("void", options)
      end

      # cancel revokes previous capture/purchase operations
      def cancel(authorization, options={})
        options[:purchaseNumber] = authorization
        commit("cancel", options)
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

      # def scrub(transcript)
        # JSON.
        # transcript.
        #   gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
        #   gsub(%r((\"card\":{\"number\":\")\d+), '\1[FILTERED]').
        #   gsub(%r((\"cvc\":\")\d+), '\1[FILTERED]')

        # urlencoded.
        # transcript.
        #   gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
        #   gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
        #   gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]')

        # XML.
        # transcript.
        #   gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
        #   gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
        #   gsub(%r((<CVN>)[^<]+(<))i, '\1[FILTERED]\2').
        #   gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2')
      # end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = 840
      CURRENCY_CODES["PEN"] = 604

      def add_invoice(post, money, options)
        post[:amount] = amount(money).to_f
        post[:purchaseNumber] = options[:order_id]
        post[:currencyId] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_payment_method(post, payment_method)
        post[:firstName] = payment_method.first_name
        post[:lastName] = payment_method.last_name
        # post[:cardtype] = payment_method.brand
        post[:cardNumber] = payment_method.number
        post[:cvv2Code] = Integer(payment_method.verification_value, 10)
        post[:expirationYear] = format(payment_method.year, :four_digits)
        post[:expirationMonth] = format(payment_method.month, :two_digits)
        # post[:cardtrackdata] = payment_method.track_data
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        # data = {}
        antifraud = {}
        billing_address = options[:billing_address] || options[:address]
        if (billing_address)
          # antifraud[:name] = billing_address[:name]
          # antifraud[:company] = billing_address[:company]
          # antifraud[:address2] = billing_address[:address2]
          # antifraud[:phone] = billing_address[:phone]
          antifraud[:billTo_street1] = billing_address[:address1]
          antifraud[:billTo_city] = billing_address[:city]
          antifraud[:billTo_state] = billing_address[:state]
          antifraud[:billTo_country] = billing_address[:country]
          antifraud[:billTo_postalCode]    = billing_address[:zip]
        end
        # post[:data] = data
        # post[:data][:antifraud] = antifraud
        post[:antifraud] = antifraud
      end

      def add_merchant_define_data(post, options)
        if (merchantDefineData = options[:merchant_define_data])
          post[:antifraud][:merchantDefineData] = merchantDefineData
        end
      end

      def add_reference(post, authorization)
        transaction_id, transaction_amount = split_authorization(authorization)
        post[:transaction_id] = transaction_id
        post[:transaction_amount] = transaction_amount
      end

      # ACTIONS = {
      #   purchase: "SALE",
      #   authorize: "AUTH",
      #   capture: "CAPTURE",
      #   void: "VOID",
      #   refund: "REFUND",
      #   store: "STORE"
      # }

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
            :authorization => response["transactionUUID"],
            :error_code => response["errorCode"]
            # {
            #   avs_result: AVSResult.new(code: response["some_avs_result_key"]),
            #   cvv_result: CVVResult.new(response["some_cvv_result_key"]),
            #   :test => test?
            # }
          )
        end
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.encode64("#{@options[:login]}:#{@options[:password]}").strip,
          "Content-Type"  => "application/json"
          # "Content-Type"  => "application/x-www-form-urlencoded;charset=UTF-8"
        }
      end

      def post_data(action, params)
        # JSON.
        params.to_json

        # urlencoded.
        # params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')

        # XML.
        # build_xml_request rather than #post_data
      end

      def base_url
        test? ? test_url : live_url
      end

      def parse(body)
        # JSON.
        JSON.parse(body)

        # urlencoded.
        # Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]
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
