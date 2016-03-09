module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CredoraxGateway < Gateway
      self.display_name = "Credorax Gateway"
      self.homepage_url = "https://www.credorax.com/"

      self.test_url = "https://intconsole.credorax.com/intenv/service/gateway"
      self.live_url = "https://example.com/live" #need approval from gateway to get production URL

      self.supported_countries = ["US"]
      self.default_currency = "EUR"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :maestro]

      def initialize(options={})
        requires!(options, :merchant_id, :cipher_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_customer_data(post, options)
        reference_action = add_reference(post, authorization)

        commit(:void, post, reference_action)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        reference_action = add_reference(post, authorization)
        add_customer_data(post, options)

        commit(:refund, post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:credit, post)
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
          gsub(%r((b1=)\d+), '\1[FILTERED]').
          gsub(%r((b5=)\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:a4] = amount(money)
        post[:a1] = options[:order_id] || generate_unique_id
        post[:a5] = options[:currency] || currency(money)
      end

      CARD_TYPES = {
        "visa" => '1',
        "mastercard" => '2',
        "maestro" => '9'
      }

      def add_payment_method(post, payment_method)
        post[:c1] = payment_method.name
        post[:b2] = CARD_TYPES[payment_method.brand] || '0'
        post[:b1] = payment_method.number
        post[:b5] = payment_method.verification_value
        post[:b4] = format(payment_method.year, :two_digits)
        post[:b3] = format(payment_method.month, :two_digits)
      end

      def add_customer_data(post, options)
        post[:d1] = options[:ip] || '127.0.0.1'
        post[:c3] = options[:email] || 'unspecified@example.com'
        if (billing_address = options[:billing_address])
          post[:c5] = billing_address[:address1]+ billing_address[:address2]
          post[:c7] = billing_address[:city]
          post[:c10]    = billing_address[:zip]
          post[:c2] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        response_id, authorization_code, request_id, action = authorization.split(";")
        post[:g2] = response_id
        post[:g3] = authorization_code
        post[:g4] = request_id
        action || :authorize
      end

      ACTIONS = {
        purchase: '1',
        authorize: '2',
        capture: '3',
        authorize_void:'4',
        refund: '5',
        credit: '6',
        purchase_void: '7',
        refund_void: '8',
        capture_void: '9'
      }

      def commit(action, params, reference_action = nil)
        raw_response = ssl_post(url, post_data(action, params, reference_action))
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: "#{response["Z1"]};#{response["Z4"]};#{response["A1"]};#{action}",
          avs_result: AVSResult.new(code: response["Z9"]),
          cvv_result: CVVResult.new(response["Z14"]),
          test: test?
        )
      end

      def sign_request(params)
        params = params.sort
        params.each { |param| param[1].gsub!(/[<>()\\]/, ' ') }
        values = params.map { |param| param[1].strip }
        Digest::MD5.hexdigest(values.join + @options[:cipher_key])
      end

      def post_data(action, params, reference_action)
        params.keys.each { |key| params[key] = params[key].to_s}
        params[:M] = @options[:merchant_id]
        params[:O] = request_action(action, reference_action)
        params[:K] = sign_request(params)
        params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end

      def request_action(action, reference_action)
        if reference_action
          ACTIONS["#{reference_action}_#{action}".to_sym]
        else
          ACTIONS[action]
        end
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]
      end

      def success_from(response)
        response["Z2"] == "0"
      end

      def message_from(response)
        if success_from(response)
          "Succeeded"
        else
          response["Z3"] || "Unable to read error message"
        end
      end
    end
  end
end
