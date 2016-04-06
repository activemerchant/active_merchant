module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentHighwayGateway < Gateway
      self.money_format = :cents
      self.test_url = 'https://v1-hub-staging.sph-test-solinor.com/'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['FI']
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.paymenthighway.fi/'
      self.display_name = 'Payment highway'

      STANDARD_ERROR_CODE_MAPPING = {}

      RESPONSE_CODE_MAPPING = {
        100 => "Request successful.",
        901 => "Invalid input. Detailed information is in the message field."
      }

      def initialize(options={})
        requires!(options, :sph_account, :sph_merchant, :account_key, :account_secret)
        @sph_account = options[:sph_account]
        @sph_merchant = options[:sph_merchant]
        @account_key = options[:account_key]
        @account_secret = options[:account_secret]
        super
      end

      def purchase(money, payment, options={})
        transactionId = initTransaction

        commit("/transaction/#{transactionId}/debit", {
          "amount": money,
          "currency": "EUR",
          "card": {
            "pan": payment.number,
            "expiry_year": payment.year.to_s,
            "expiry_month": payment.month.to_s,
            "cvc": payment.verification_value
          }
        }.to_json)
      end

      #def authorize(money, payment, options={})
        #post = {}
        #add_invoice(post, money, options)
        #add_payment(post, payment)
        #add_address(post, payment, options)
        #add_customer_data(post, options)

        #commit('authonly', post)
      #end

      #def capture(money, authorization, options={})
        #commit('capture', post)
      #end

      #def refund(money, authorization, options={})
        #commit('refund', post)
      #end

      #def void(authorization, options={})
        #commit('void', post)
      #end

      #def verify(credit_card, options={})
        #MultiResponse.run(:use_first_response) do |r|
          #r.process { authorize(100, credit_card, options) }
          #r.process(:ignore_result) { void(r.authorization, options) }
        #end
      #end

      #def supports_scrubbing?
        #true
      #end

      #def scrub(transcript)
        #transcript
      #end

      private

      #def add_customer_data(post, options)
      #end

      #def add_address(post, creditcard, options)
      #end

      #def add_invoice(post, money, options)
        #post[:amount] = amount(money)
        #post[:currency] = (options[:currency] || currency(money))
      #end

      #def add_payment(post, payment)
      #end

      def commit(action, payload)
        url = (test? ? test_url : live_url)
        json = payload
        request_id = generate_request_id
        timestamp = Time.now.utc.xmlschema
        signature = generate_signature("POST", action, request_id, timestamp, json)
        response = JSON.parse(ssl_post(url + action, json, headers(request_id, timestamp, signature)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def generate_signature method, action, request_id, timestamp, payload
        contents = [method]
        contents << action
        contents << "sph-account:#{@sph_account}"
        contents << "sph-merchant:#{@sph_merchant}"
        contents << "sph-request-id:#{request_id}"
        contents << "sph-timestamp:#{timestamp}"
        contents << payload
        OpenSSL::HMAC.hexdigest('sha256', @account_secret, contents.join("\n"))
      end

      def headers request_id, timestamp, signature
        {
          "Content-Type" => "application/json; charset=utf-8",
          "SPH-Account" =>  @sph_account,
          "SPH-Merchant" => @sph_merchant,
          "SPH-Timestamp" => timestamp,
          "SPH-Request-Id" => request_id,
          "Signature" => "SPH1 #{@account_key} #{signature}"
        }
      end

      def generate_request_id
        SecureRandom.uuid
      end

      def success_from(response)
        response_code(response) == 100
      end

      def message_from(response)
        RESPONSE_CODE_MAPPING[response_code(response)]
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          response_code(response)
        end
      end

      def initTransaction
        commit("/transaction", "").params["id"]
      end

      def response_code(response)
        response["result"]["code"]
      end
    end
  end
end
