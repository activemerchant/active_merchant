require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class KomojuGateway < Gateway
      self.test_url = "https://sandbox.komoju.com/api/v1"
      self.live_url = "https://komoju.com/api/v1"
      self.supported_countries = ['JP']
      self.default_currency = 'JPY'
      self.money_format = :cents
      self.homepage_url = 'https://www.komoju.com/'
      self.display_name = 'Komoju'
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      STANDARD_ERROR_CODE_MAPPING = {
        "bad_verification_value" => "incorrect_cvc",
        "card_expired" => "expired_card",
        "card_declined" => "card_declined",
        "invalid_number" => "invalid_number"
      }

      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        super
      end

      def purchase(money, payment, options = {})
        params = {
          :amount => amount(money),
          :description => options[:description],
          :payment_details => payment_details(payment, options),
          :currency => options[:currency] || currency(money)
        }
        params[:external_order_num] = options[:order_id] if options[:order_id]
        params[:tax] = options[:tax] if options[:tax]
        params[:fraud_details] = fraud_details(options) unless fraud_details(options).empty?

        commit("/payments", params)
      end

      def refund(money, identification, options = {})
        commit("/payments/#{identification}/refund", {})
      end

      private

      def payment_details(payment, options)
        details = if payment.is_a?(CreditCard)
                    credit_card_payment_details(payment, options)
                  else
                    payment
                  end

        details[:email] = options[:email] if options[:email]
        details
      end

      def fraud_details(options)
        details = {}
        details[:customer_ip] = options[:ip] if options[:ip]
        details[:customer_email] = options[:email] if options[:email]
        details[:browser_language] = options[:browser_language] if options[:browser_language]
        details[:browser_user_agent] = options[:browser_user_agent] if options[:browser_user_agent]
        details
      end

      def credit_card_payment_details(card, options)
        details = {}
        details[:type] = 'credit_card'
        details[:number] = card.number
        details[:month] = card.month
        details[:year] = card.year
        details[:verification_value] = card.verification_value
        details[:given_name] = card.first_name
        details[:family_name] = card.last_name
        details
      end

      def api_request(path, data)
        raw_response = nil
        begin
          raw_response = ssl_post("#{url}#{path}", data, headers)
        rescue ResponseError => e
          raw_response = e.response.body
        end

        JSON.parse(raw_response)
      end

      def commit(path, params)
        response = api_request(path, params.to_json)
        success = !response.key?("error")
        message = success ? "Transaction succeeded" : response["error"]["message"]
        Response.new(success, message, response,
                     :test => test?,
                     :error_code => success ? nil : error_code(response["error"]["code"]),
                     :authorization => success ? response["id"] : nil)
      end

      def error_code(code)
        STANDARD_ERROR_CODE_MAPPING[code] || code
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":").strip,
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "User-Agent" => "Komoju/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end
    end
  end
end
