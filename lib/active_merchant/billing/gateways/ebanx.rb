module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EbanxGateway < Gateway
      self.test_url = 'https://sandbox.ebanx.com/ws/'
      self.live_url = 'https://api.ebanx.com/ws/'

      self.supported_countries = ['BR', 'MX']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]

      self.homepage_url = 'http://www.ebanx.com/'
      self.display_name = 'Ebanx'

      CARD_BRAND = {
        visa: "visa",
        master: "master_card",
        american_express: "amex",
        discover: "discover",
        diners_club: "diners"
      }

      URL_MAP = {
        purchase: "direct",
        authorize: "direct",
        capture: "capture",
        refund: "refund",
        void: "cancel"
      }

      HTTP_METHOD = {
        purchase: :post,
        authorize: :post,
        capture: :get,
        refund: :post,
        void: :get
      }

      def initialize(options={})
        requires!(options, :integration_key)
        super
      end

      def purchase(money, payment, options={})
        post = { payment: {} }
        add_integration_key(post)
        add_operation(post)
        add_invoice(post, money, options)
        add_customer_data(post, payment, options)
        add_payment(post, payment)
        add_address(post, options)

        commit(:purchase, post)
      end

      def authorize(money, payment, options={})
        post = { payment: {} }
        add_integration_key(post)
        add_operation(post)
        add_invoice(post, money, options)
        add_customer_data(post, payment, options)
        add_payment(post, payment)
        add_address(post, options)
        post[:payment][:creditcard][:auto_capture] = false

        commit(:authorize, post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_integration_key(post)
        post[:hash] = authorization
        post[:amount] = amount(money)

        commit(:capture, post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_integration_key(post)
        add_operation(post)
        add_authorization(post, authorization)
        post[:amount] = amount(money)
        post[:description] = options[:description]

        commit(:refund, post)
      end

      def void(authorization, options={})
        post = {}
        add_integration_key(post)
        add_authorization(post, authorization)

        commit(:void, post)
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
          gsub(/(integration_key\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(card_number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(card_cvv\\?":\\?")(\d*)/, '\1[FILTERED]')
      end

      private

      def add_integration_key(post)
        post[:integration_key] = @options[:integration_key].to_s
      end

      def add_operation(post)
        post[:operation] = "request"
      end

      def add_authorization(post, authorization)
        post[:hash] = authorization
      end

      def add_customer_data(post, payment, options)
        post[:payment][:name] = payment.name
        post[:payment][:email] = options[:email] || "unspecified@example.com"
        post[:payment][:document] = options[:document]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:payment][:address] = address[:address1].split[1..-1].join(" ") if address[:address1]
          post[:payment][:street_number] = address[:address1].split.first if address[:address1]
          post[:payment][:city] = address[:city]
          post[:payment][:state] = address[:state]
          post[:payment][:zipcode] = address[:zip]
          post[:payment][:country] = address[:country]
          post[:payment][:phone_number] = address[:phone]
        end
      end

      def add_invoice(post, money, options)
        post[:payment][:amount_total] = amount(money)
        post[:payment][:currency_code] = (options[:currency] || currency(money))
        post[:payment][:merchant_payment_code] = options[:order_id]
      end

      def add_payment(post, payment)
        post[:payment][:payment_type_code] = CARD_BRAND[payment.brand.to_sym]
        post[:payment][:creditcard] = {
          card_number: payment.number,
          card_name: payment.name,
          card_due_date: "#{payment.month}/#{payment.year}",
          card_cvv: payment.verification_value
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = url_for((test? ? test_url : live_url), action, parameters)
        response = parse(ssl_request(HTTP_METHOD[action], url, post_data(action, parameters), {}))

        success = success_from(action, response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response, success)
        )
      end

      def success_from(action, response)
        if [:purchase, :capture, :refund].include?(action)
          response.try(:[], "payment").try(:[], "status") == "CO"
        elsif action == :authorize
          response.try(:[], "payment").try(:[], "status") == "PE"
        elsif action == :void
          response.try(:[], "payment").try(:[], "status") == "CA"
        else
          false
        end
      end

      def message_from(response)
        return response["status_message"] if response["status"] == "ERROR"
        response.try(:[], "payment").try(:[], "transaction_status").try(:[], "description")
      end

      def authorization_from(response)
        response.try(:[], "payment").try(:[], "hash")
      end

      def post_data(action, parameters = {})
        return nil if requires_http_get(action)
        return convert_to_url_form_encoded(parameters) if action == :refund
        "request_body=#{parameters.to_json}"
      end

      def url_for(hostname, action, parameters)
        return hostname + URL_MAP[action] + "?#{convert_to_url_form_encoded(parameters)}" if requires_http_get(action)
        hostname + URL_MAP[action]
      end

      def requires_http_get(action)
        return true if [:capture, :void].include?(action)
        false
      end

      def convert_to_url_form_encoded(parameters)
        parameters.map do |key, value|
          next if value != false && value.blank?
          "#{key}=#{value}"
        end.compact.join("&")
      end

      def error_code_from(response, success)
        unless success
          return response["status_code"] if response["status"] == "ERROR"
          response.try(:[], "payment").try(:[], "transaction_status").try(:[], "code")
        end
      end
    end
  end
end
