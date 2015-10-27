module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DibsGateway < Gateway
      self.display_name = "DIBS"
      self.homepage_url = "http://www.dibspayment.com/"

      self.live_url = "https://api.dibspayment.com/merchant/v1/JSON/Transaction/"

      self.supported_countries = ["US", "FI", "NO", "SE", "GB"]
      self.default_currency = "USD"
      self.money_format = :cents
      self.ssl_version = :TLSv1
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :merchant_id, :secret_key)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run(false) do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(amount, r.authorization, options) }
        end
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_amount(post, amount)
        add_invoice(post, amount, options)
        if (payment_method.respond_to?(:number))
          add_payment_method(post, payment_method, options)
          commit(:authorize, post)
        else
          add_ticket_id(post, payment_method)
          commit(:authorize_ticket, post)
        end

      end

      def capture(amount, authorization, options={})
        post = {}
        add_amount(post, amount)
        add_reference(post, authorization)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)

        commit(:void, post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_amount(post, amount)
        add_reference(post, authorization)

        commit(:refund, post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        post = {}

        add_invoice(post, 0, options)
        add_payment_method(post, payment_method, options)

        commit(:store, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(("cardNumber\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvc\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = "840"
      CURRENCY_CODES["DKK"] = "208"
      CURRENCY_CODES["NOK"] = "578"
      CURRENCY_CODES["SEK"] = "752"
      CURRENCY_CODES["GBP"] = "826"
      CURRENCY_CODES["EUR"] = "978"

      def add_invoice(post, money, options)
        post[:orderId] = options[:order_id] || generate_unique_id
        post[:currency] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_ticket_id(post, payment_method)
        post[:ticketId] = payment_method
      end

      def add_payment_method(post, payment_method, options)
        post[:cardNumber] = payment_method.number
        post[:cvc] = payment_method.verification_value if payment_method.verification_value
        post[:expYear] = format(payment_method.year, :two_digits)
        post[:expMonth] = payment_method.month

        post[:startMonth] = payment_method.start_month if payment_method.start_month
        post[:startYear] = payment_method.start_year if payment_method.start_year
        post[:issueNumber] = payment_method.issue_number if payment_method.issue_number
        post[:clientIp] = options[:ip] || "127.0.0.1"
        post[:test] = true if test?
      end


      def add_reference(post, authorization)
        post[:transactionId] = authorization
      end

      def add_amount(post, amount)
        post[:amount] = amount
      end

      ACTIONS = {
        authorize: "AuthorizeCard",
        authorize_ticket: "AuthorizeTicket",
        capture: "CaptureTransaction",
        void: "CancelTransaction",
        refund: "RefundTransaction",
        store: "CreateTicket"
      }

      def commit(action, post)
        post[:merchantId] = @options[:merchant_id]

        data = build_request(post)
        raw = parse(ssl_post(url(action), "request=#{data}", headers))
        succeeded = success_from(raw)
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          authorization: authorization_from(post, raw),
          test: test?
        )
      rescue JSON::ParserError
        unparsable_response(raw)
      end

      def headers
        {
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      end

      def build_request(post)
        add_hmac(post)
        post.to_json
      end

      def add_hmac(post)
        data = post.sort.collect { |key, value| "#{key}=#{value.to_s}" }.join("&")
        digest = OpenSSL::Digest.new('sha256')
        key = [@options[:secret_key]].pack('H*')
        post[:MAC] = OpenSSL::HMAC.hexdigest(digest, key, data)
      end

      def url(action)
        live_url + ACTIONS[action]
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(raw_response)
        raw_response["status"] == "ACCEPT"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response["status"] + ": " + response["declineReason"] || "Unable to read error message"
        end
      end

      def authorization_from(request, response)
        response['transactionId'] || response['ticketId'] || request[:transactionId]
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from Dibs. Please contact Dibs if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
