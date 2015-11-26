module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutV2Gateway < Gateway
      self.display_name = "Checkout.com V2 Gateway"
      self.homepage_url = "https://www.checkout.com/"
      self.live_url = "https://api2.checkout.com/v2"
      self.test_url = "http://sandbox.checkout.com/api2/v2"

      self.supported_countries = ['AD', 'AT', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FO', 'FI', 'FR', 'GB', 'GI', 'GL', 'GR', 'HR', 'HU', 'IE', 'IS', 'IL', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SI', 'SM', 'SK', 'SJ', 'TR', 'VA']
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      def initialize(options={})
        requires!(options, :secret_key)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(amount, r.authorization, options) }
        end
      end

      def authorize(amount, payment_method, options={})
        post = {}
        post[:autoCapture] = "n"
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)

        commit(:capture, post, authorization)
      end

      def void(authorization, options={})
        post = {}
        commit(:void, post, authorization)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)

        commit(:refund, post, authorization)
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
          gsub(%r((Authorization: )[^\\]*)i, '\1[FILTERED]').
          gsub(%r(("number\\":\\")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\":\\")\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:value] = amount(money)
        post[:trackId] = options[:order_id]
        post[:currency] = options[:currency] || currency(money)
      end

      def add_payment_method(post, payment_method)
        post[:card] = {}
        post[:card][:name] = payment_method.name
        post[:card][:number] = payment_method.number
        post[:card][:cvv] = payment_method.verification_value
        post[:card][:expiryYear] = format(payment_method.year, :four_digits)
        post[:card][:expiryMonth] = format(payment_method.month, :two_digits)
      end

      def add_customer_data(post, options)
        post[:email] = options[:email] || "unspecified@example.com"
        address = options[:billing_address]
        if(address && post[:card])
          post[:card][:billingDetails] = {}
          post[:card][:billingDetails][:address1] = address[:address1]
          post[:card][:billingDetails][:address2] = address[:address2]
          post[:card][:billingDetails][:city] = address[:city]
          post[:card][:billingDetails][:state] = address[:state]
          post[:card][:billingDetails][:country] = address[:country]
          post[:card][:billingDetails][:postcode] = address[:zip]
          post[:card][:billingDetails][:phone] = { number: address[:phone] } unless address[:phone].blank?
        end
      end

      def commit(action, post, authorization = nil)
        begin
          raw_response = ssl_post(url(post, action, authorization), post.to_json, headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /4\d\d/)
          response = parse(e.response.body)
        end

        succeeded = success_from(response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(succeeded, response),
          test: test?,
          avs_result: avs_result(action, response),
          cvv_result: cvv_result(action, response))
      end

      def headers
        {
          "Authorization" => @options[:secret_key],
          "Content-Type"  => "application/json;charset=UTF-8"
        }
      end

      def url(post, action, authorization)
        if action == :authorize
          "#{base_url}/charges/card"
        else
          "#{base_url}/charges/#{authorization}/#{action}"
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def avs_result(action, response)
        action == :purchase ? AVSResult.new(code: response["card"]["avsCheck"]) : nil
      end

      def cvv_result(action, response)
        action == :purchase ? CVVResult.new(response["card"]["cvvCheck"]) : nil
      end

      def parse(body)
        JSON.parse(body)
        rescue JSON::ParserError
          {
            "message" => "Invalid JSON response received from CheckoutV2Gateway. Please contact CheckoutV2Gateway if you continue to receive this message.",
            "raw_response" => scrub(body)
          }
      end

      def success_from(response)
        response["responseCode"] == ("10000" || "10100")
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        elsif response["errors"]
          response["message"] + ": " + response["errors"].first
        else
          response["responseMessage"] || response["message"] || "Unable to read error message"
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        "20014" => STANDARD_ERROR_CODE[:invalid_number],
        "20100" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "20054" => STANDARD_ERROR_CODE[:expired_card],
        "40104" => STANDARD_ERROR_CODE[:incorrect_cvc],
        "40108" => STANDARD_ERROR_CODE[:incorrect_zip],
        "40111" => STANDARD_ERROR_CODE[:incorrect_address],
        "20005" => STANDARD_ERROR_CODE[:card_declined],
        "20088" => STANDARD_ERROR_CODE[:processing_error],
        "20001" => STANDARD_ERROR_CODE[:call_issuer],
        "30004" => STANDARD_ERROR_CODE[:pickup_card]
      }

      def authorization_from(raw)
        raw["id"]
      end

      def error_code_from(succeeded, response)
        succeeded ? nil : STANDARD_ERROR_CODE_MAPPING[response["responseCode"]]
      end
    end
  end
end
