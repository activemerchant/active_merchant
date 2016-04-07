module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Latitude19Gateway < Gateway
      self.display_name = "Latitude19 Gateway"
      self.homepage_url = "http://www.l19tech.com"

      self.live_url = "https://gateway.l19tech.com/payments/"
      self.test_url = "https://gateway-sb.l19tech.com/payments/"

      self.supported_countries = ["US", "CA"]
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      RESPONSE_CODE_MAPPING = {
        '100' => 'Approved',
        '101' => 'Local duplicate detected',
        '102' => 'Accepted local capture with no match',
        '103' => 'Auth succeeded but capture failed',
        '104' => 'Auth succeeded but failed to save info',
        '200' => STANDARD_ERROR_CODE[:card_declined],
        '300' => 'Processor reject',
        '301' => 'Local reject on user/password',
        '302' => 'Local reject',
        '303' => 'Processor unknown response',
        '304' => 'Error parsing processor response',
        '305' => 'Processor auth succeeded but settle failed',
        '306' => 'Processor auth succeeded settle status unknown',
        '307' => 'Processor settle status unknown',
        '308' => 'Processor duplicate',
        '400' => 'Not submitted',
        '401' => 'Terminated before request submitted',
        '402' => 'Local server busy',
        '500' => 'Submitted not returned',
        '501' => 'Terminated before response returned',
        '502' => 'Processor returned timeout status',
        '600' => 'Failed local capture with no match',
        '601' => 'Failed local capture',
        '700' => 'Failed local void (not in capture file)',
        '701' => 'Failed local void',
        '800' => 'Failed local refund (not authorized)',
        '801' => 'Failed local refund'
      }

      BRAND_MAP = {
        "master" => "MC",
        "visa" => "VI",
        "american_express" => "AX",
        "discover" => "DS",
        "diners_club" => "DC",
        "jcb" => "JC"
      }

      def initialize(options={})
        requires!(options, :account_number, :configuration_id, :secret)
        super
      end

      def purchase(amount, payment_method, options={})
        if options[:account_token]
          auth_or_sale("sale", nil, amount, payment_method, options)
        else
          MultiResponse.run() do |r|
            r.process { get_session(options) }
            r.process { get_token(r.authorization, payment_method, options) }
            r.process { auth_or_sale("sale", r.authorization, amount, payment_method, options) }
          end
        end
      end

      def authorize(amount, payment_method, options={})
        if options[:account_token]
          auth_or_sale("auth", nil, amount, payment_method, options)
        else
          MultiResponse.run() do |r|
            r.process { get_session(options) }
            r.process { get_token(r.authorization, payment_method, options) }
            r.process { auth_or_sale("auth", r.authorization, amount, payment_method, options) }
          end
        end
      end

      def capture(amount, authorization, options={})
        post = {}
        post[:method] = "deposit"
        add_request_id(post)

        params = {}

        _, params[:pgwTID] = split_authorization(authorization)

        add_invoice(params, amount, options)
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("v1/", post)
      end

      def void(authorization, options={})
        method, pgwTID = split_authorization(authorization)
        case method
        when "auth"
          reverse_or_void("reversal", pgwTID, options)
        when "deposit", "sale"
          reverse_or_void("void", pgwTID, options)
        else
          message = "Unsupported operation. Only successful and active - Purchase, Authorize and Capture transactions can be voided."
          return Response.new(false, message)
        end
      end

      def credit(amount, payment_method, options={})
        if options[:account_token]
          refundWithCard(nil, amount, payment_method, options)
        else
          MultiResponse.run() do |r|
            r.process { get_session(options) }
            r.process { get_token(r.authorization, payment_method, options) }
            r.process { refundWithCard(r.authorization, amount, payment_method, options) }
          end
        end
      end

      def verify(payment_method, options={}, action=nil)
        if options[:account_token]
          verifyOnly(action, nil, payment_method, options)
        else
          MultiResponse.run() do |r|
            r.process { get_session(options) }
            r.process { get_token(r.authorization, payment_method, options) }
            r.process { verifyOnly(action, r.authorization, payment_method, options) }
          end
        end
      end

      def store(payment_method, options={})
        verify(payment_method, options, "store")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\"pgwAccountNumber\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"pgwConfigurationId\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"cardNumber\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"cvv\\\":\\\")\d+), '\1[FILTERED]')
      end


      private

      def add_request_id(post)
        post[:id] = SecureRandom.hex(16)
      end

      def message(params, method)
        if method == "getSession"
          params[:pgwAccountNumber] + "|" + params[:pgwConfigurationId] + "|" + params[:requestTimeStamp] + "|" + method
        else
          params[:pgwAccountNumber] + "|" + params[:pgwConfigurationId] + "|" + (params[:orderNumber] || "") + "|" + method + "|" + (params[:amount] || "") + "|" + (params[:sessionToken] || "") + "|" + (params[:accountToken] || "")
        end
      end

      def get_session(options={})
        post = {}
        post[:method] = "getSession"
        add_request_id(post)

        params = {}
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("session", post)
      end

      def get_token(authorization, payment_method, options={})
        post = {}
        post[:method] = "tokenize"
        add_request_id(post)

        params = {}
        _, params[:sessionId] = split_authorization(authorization)
        params[:cardNumber] = payment_method.number

        post[:params] = [params]
        commit("token", post)
      end

      def auth_or_sale(method, authorization, amount, payment_method, options={})
        post = {}
        post[:method] = method
        add_request_id(post)

        params = {}
        add_token(authorization, params, options)
        add_invoice(params, amount, options)
        add_payment_method(params, payment_method)
        add_customer_data(params, options)
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("v1/", post)
      end

      def verifyOnly(action, authorization, payment_method, options={})
        post = {}
        post[:method] = "verifyOnly"
        add_request_id(post)

        params = {}
        add_token(authorization, params, options)
        params[:requestAccountToken] = "1" if action == "store"
        add_invoice(params, 0, options)
        add_payment_method(params, payment_method)
        add_customer_data(params, options)
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("v1/", post)
      end

      def refundWithCard(authorization, amount, payment_method, options={})
        post = {}
        post[:method] = "refundWithCard"
        add_request_id(post)

        params = {}
        add_token(authorization, params, options)
        add_invoice(params, amount, options)
        add_payment_method(params, payment_method)
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("v1/", post)
      end

      def reverse_or_void(method, pgwTID, options={})
        post = {}
        post[:method] = method
        add_request_id(post)

        params = {}
        params[:orderNumber] = options[:order_id]
        params[:pgwTID] = pgwTID
        add_credentials(params, post[:method])

        post[:params] = [params]
        commit("v1/", post)
      end

      def add_token(authorization, params, options={})
        if options[:account_token]
          params[:accountToken] = options[:account_token]
        else
          _, params[:sessionToken] = split_authorization(authorization)
        end
      end

      def add_credentials(params, method)
        params[:pgwAccountNumber] = @options[:account_number]
        params[:pgwConfigurationId] = @options[:configuration_id]

        params[:requestTimeStamp] = Time.now.getutc.strftime("%Y%m%d%H%M%S") if method == "getSession"

        params[:pgwHMAC] = OpenSSL::HMAC.hexdigest('sha512', @options[:secret], message(params, method))
      end

      def add_invoice(params, money, options)
        params[:amount] = amount(money)
        params[:orderNumber] = options[:order_id]
        params[:transactionClass] = "eCommerce" || options[:transaction_class]
      end

      def add_payment_method(params, payment_method)
        params[:cardExp] = format(payment_method.month, :two_digits).to_s + "/" + format(payment_method.year, :two_digits).to_s
        params[:cardType] = BRAND_MAP[payment_method.brand.to_s]
        params[:cvv] = payment_method.verification_value
        params[:firstName] = payment_method.first_name
        params[:lastName] = payment_method.last_name
      end

      def add_customer_data(params, options)
        if (billing_address = options[:billing_address] || options[:address])
          params[:address1] = billing_address[:address1]
          params[:address2] = billing_address[:address2]
          params[:city] = billing_address[:city]
          params[:stateProvince] = billing_address[:state]
          params[:zipPostalCode] = billing_address[:zip]
          params[:countryCode] = billing_address[:country]
        end
      end

      def commit(endpoint, post)
        begin
          raw_response = ssl_post(url() + endpoint, post_data(post), headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response_error(raw_response)
        rescue JSON::ParserError
          unparsable_response(raw_response)
        else
          success = success_from(response)
          Response.new(
            success,
            message_from(response),
            response,
            authorization: success ? authorization_from(response, post[:method]) : nil,
            avs_result: success ? avs_from(response) : nil,
            cvv_result: success ? cvv_from(response) : nil,
            error_code: success ? nil : error_from(response),
            test: test?
          )
        end
      end

      def headers
        {
          "Content-Type"  => "application/json"
        }
      end

      def post_data(params)
        params.to_json
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        return false if response["result"].nil? || response["error"]

        if response["result"].key?("pgwResponseCode")
          response["error"].nil? && response["result"]["lastActionSucceeded"] == 1 && response["result"]["pgwResponseCode"] == "100"
        else
          response["error"].nil? && response["result"]["lastActionSucceeded"] == 1
        end
      end

      def message_from(response)
        return response["error"] || "HTTP Response Error" unless response.key?("result")

        return response["error"] if response["error"]

        if response["result"].key?("pgwResponseCode")
          (RESPONSE_CODE_MAPPING[response["result"]["pgwResponseCode"]] || "") + "|" + (response["result"]["responseText"] || "")
        else
          response["result"]["lastActionSucceeded"] == 1 ? "Succeeded" : "Failed"
        end
      end

      def error_from(response)
        return response["error"] if response["error"]

        if response["result"].key?("pgwResponseCode")
          "pgwResponseCode|" + response["result"]["pgwResponseCode"] + "|pgwResponseCodeDescription|" + RESPONSE_CODE_MAPPING[response["result"]["pgwResponseCode"]] + "|responseText|" + (response["result"]["responseText"] || "") + "|processorResponseCode|" + (response["result"]["processor"]["responseCode"] || "")
        end
      end

      def authorization_from(response, method)
        method + "|" + (
          response["result"]["sessionId"] ||
          response["result"]["sessionToken"] ||
          response["result"]["pgwTID"] ||
          response["result"]["accountToken"]
        )
      end

      def split_authorization(authorization)
        authorization.split("|")
      end

      def avs_from(response)
        response["result"].key?("avsResponse") ? AVSResult.new(code: response["result"]["avsResponse"]) : nil
      end

      def cvv_from(response)
        response["result"].key?("cvvResponse") ? CVVResult.new(response["result"]["cvvResponse"]) : nil
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
            :test => test?
          )
        end
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from Latitude19Gateway. Please contact Latitude19Gateway if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
    end
  end
end
