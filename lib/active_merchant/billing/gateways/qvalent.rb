module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QvalentGateway < Gateway
      self.display_name = "Qvalent"
      self.homepage_url = "https://www.qvalent.com/"

      self.test_url = "https://ccapi.client.support.qvalent.com/post/CreditCardAPIReceiver"
      self.live_url = "https://ccapi.client.qvalent.com/post/CreditCardAPIReceiver"

      self.supported_countries = ["AU"]
      self.default_currency = "AUD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners]

      def initialize(options={})
        requires!(options, :username, :password, :merchant)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_order_number(post, options)
        add_payment_method(post, payment_method)
        add_verification_value(post, payment_method)
        add_customer_data(post, options)

        commit("capture", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization, options)
        add_customer_data(post, options)

        commit("refund", post)
      end

      def store(payment_method, options = {})
        post = {}
        add_payment_method(post, payment_method)
        add_card_reference(post)

        commit("registerAccount", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((&?customer.password=)[^&]*), '\1[FILTERED]').
          gsub(%r((&?card.PAN=)[^&]*), '\1[FILTERED]').
          gsub(%r((&?card.CVN=)[^&]*), '\1[FILTERED]')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["AUD"] = "AUD"
      CURRENCY_CODES["INR"] = "INR"

      def add_invoice(post, money, options)
        post["order.amount"] = amount(money)
        post["card.currency"] = CURRENCY_CODES[options[:currency] || currency(money)]
        post["order.ECI"] = "SSL"
      end

      def add_payment_method(post, payment_method)
        post["card.cardHolderName"] = payment_method.name
        post["card.PAN"] = payment_method.number
        post["card.expiryYear"] = format(payment_method.year, :two_digits)
        post["card.expiryMonth"] = format(payment_method.month, :two_digits)
      end

      def add_verification_value(post, payment_method)
        post["card.CVN"] = payment_method.verification_value
      end

      def add_card_reference(post)
        post["customer.customerReferenceNumber"] = options[:order_id]
      end

      def add_reference(post, authorization, options)
        post["customer.originalOrderNumber"] = authorization
        add_order_number(post, options)
      end

      def add_order_number(post, options)
        post["customer.orderNumber"] = options[:order_id] || SecureRandom.uuid
      end

      def add_customer_data(post, options)
        post["order.ipAddress"] = options[:ip]
      end

      def commit(action, post)
        post["customer.username"] = @options[:username]
        post["customer.password"] = @options[:password]
        post["customer.merchant"] = @options[:merchant]
        post["order.type"] = action

        data = build_request(post)
        raw = parse(ssl_post(url(action), data, headers))

        succeeded = success_from(raw["response.responseCode"])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          authorization: raw["response.orderNumber"] || raw["response.customerReferenceNumber"],
          error_code: error_code_from(succeeded, raw),
          test: test?
        )
      end

      def headers
        {
          "Content-Type"  => "application/x-www-form-urlencoded"
        }
      end

      def build_request(post)
        post.to_query + "&message.end"
      end

      def url(action)
        (test? ? test_url : live_url)
      end

      def parse(body)
        result = {}
        body.to_s.each_line do |pair|
          result[$1] = $2 if pair.strip =~ /\A([^=]+)=(.+)\Z/im
        end
        result
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      SUCCESS_CODES = %w(00 08 10 11 16 QS QZ)

      def success_from(response)
        SUCCESS_CODES.include?(response)
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response["response.text"] || "Unable to read error message"
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        "14" => STANDARD_ERROR_CODE[:invalid_number],
        "QQ" => STANDARD_ERROR_CODE[:invalid_cvc],
        "33" => STANDARD_ERROR_CODE[:expired_card],
        "NT" => STANDARD_ERROR_CODE[:incorrect_address],
        "12" => STANDARD_ERROR_CODE[:card_declined],
        "06" => STANDARD_ERROR_CODE[:processing_error],
        "01" => STANDARD_ERROR_CODE[:call_issuer],
        "04" => STANDARD_ERROR_CODE[:pickup_card],
      }

      def error_code_from(succeeded, response)
        succeeded ? nil : STANDARD_ERROR_CODE_MAPPING[response["response.responseCode"]]
      end
    end
  end
end
