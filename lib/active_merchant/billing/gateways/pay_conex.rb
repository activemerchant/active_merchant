module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayConexGateway < Gateway
      include Empty

      self.test_url = "https://cert.payconex.net/api/qsapi/3.8/"
      self.live_url = "https://secure.payconex.net/api/qsapi/3.8/"

      self.supported_countries = %w(US CA)
      self.default_currency = "USD"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      self.homepage_url = "http://www.bluefincommerce.com/"
      self.display_name = "PayConex"

      def initialize(options={})
        requires!(options, :account_id, :api_accesskey)
        super
      end

      def purchase(money, payment_method, options={})
        post = {}
        add_auth_purchase_params(post, money, payment_method, options)
        commit("SALE", post)
      end

      def authorize(money, payment_method, options={})
        post = {}
        add_auth_purchase_params(post, money, payment_method, options)
        commit("AUTHORIZATION", post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_reference_params(post, authorization, options)
        add_amount(post, money, options)
        commit("CAPTURE", post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_reference_params(post, authorization, options)
        add_amount(post, money, options)
        commit("REFUND", post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference_params(post, authorization, options)
        commit("REVERSAL", post)
      end

      def credit(money, payment_method, options={})
        if payment_method.is_a?(String)
          raise ArgumentError, "Reference credits are not supported. Please supply the original credit card or use the #refund method."
        end

        post = {}
        add_auth_purchase_params(post, money, payment_method, options)
        commit("CREDIT", post)
      end

      def verify(payment_method, options={})
        authorize(0, payment_method, options)
      end

      def store(payment_method, options={})
        post = {}
        add_credentials(post)
        add_payment_method(post, payment_method)
        add_address(post, options)
        add_common_options(post, options)
        commit("STORE", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        force_utf8(transcript).
          gsub(%r((api_accesskey=)\w+), '\1[FILTERED]').
          gsub(%r((card_number=)\w+), '\1[FILTERED]').
          gsub(%r((card_verification=)\w+), '\1[FILTERED]')
      end

      private

      def force_utf8(string)
        return nil unless string
        binary = string.encode("BINARY", invalid: :replace, undef: :replace, replace: "?")   # Needed for Ruby 2.0 since #encode is a no-op if the string is already UTF-8. It's not needed for Ruby 2.1 and up since it's not a no-op there.
        binary.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end

      def add_credentials(post)
        post[:account_id] = @options[:account_id]
        post[:api_accesskey] = @options[:api_accesskey]
      end

      def add_auth_purchase_params(post, money, payment_method, options)
        add_credentials(post)
        add_payment_method(post, payment_method)
        add_address(post, options)
        add_common_options(post, options)
        add_amount(post, money, options)
        add_if_present(post, :email, options[:email])
      end

      def add_reference_params(post, authorization, options)
        add_credentials(post)
        add_common_options(post, options)
        add_token_id(post, authorization)
      end

      def add_amount(post, money, options)
        post[:transaction_amount] = amount(money)
        currency_code = (options[:currency] || currency(money))
        add_if_present(post, :currency, currency_code)
      end

      def add_payment_method(post, payment_method)
        case payment_method
        when String
          add_token_payment_method(post, payment_method)
        when Check
          add_check(post, payment_method)
        else
          if payment_method.respond_to?(:track_data) && payment_method.track_data.present?
            add_card_present_payment_method(post, payment_method)
          else
            add_credit_card(post, payment_method)
          end
        end
      end

      def add_credit_card(post, payment_method)
        post[:tender_type] = "CARD"
        post[:card_number] = payment_method.number
        post[:card_expiration] = expdate(payment_method)
        post[:card_verification] = payment_method.verification_value
        post[:first_name] = payment_method.first_name
        post[:last_name] = payment_method.last_name
      end

      def add_token_payment_method(post, payment_method)
        post[:tender_type] = "CARD"
        post[:token_id] = payment_method
        post[:reissue] = true
      end

      def add_card_present_payment_method(post, payment_method)
        post[:tender_type] = "CARD"
        post[:card_tracks] = payment_method.track_data
      end

      def add_check(post, payment_method)
        post[:tender_type] = "ACH"
        post[:first_name] = payment_method.first_name
        post[:last_name] = payment_method.last_name
        post[:bank_account_number] = payment_method.account_number
        post[:bank_routing_number] = payment_method.routing_number
        post[:check_number] = payment_method.number
        add_if_present(post, :ach_account_type, payment_method.account_type)
      end

      def add_address(post, options)
        address = options[:billing_address]
        return unless address

        add_if_present(post, :street_address1, address[:address1])
        add_if_present(post, :street_address2, address[:address2])
        add_if_present(post, :city, address[:city])
        add_if_present(post, :state, address[:state])
        add_if_present(post, :zip, address[:zip])
        add_if_present(post, :country, address[:country])
        add_if_present(post, :phone, address[:phone])
      end

      def add_common_options(post, options)
        add_if_present(post, :transaction_description, options[:description])
        add_if_present(post, :custom_id, options[:custom_id])
        add_if_present(post, :custom_data, options[:custom_data])
        add_if_present(post, :ip_address, options[:ip])
        add_if_present(post, :payment_type, options[:payment_type])
        add_if_present(post, :cashier, options[:cashier])

        post[:disable_cvv] = options[:disable_cvv] unless options[:disable_cvv].nil?
        post[:response_format] = 'JSON'
      end

      def add_if_present(post, key, value)
        post[key] = value unless empty?(value)
      end

      def add_token_id(post, authorization)
        post[:token_id] = authorization
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, params)
        raw_response = ssl_post(url, post_data(action, params))
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: response["transaction_id"],
          :avs_result => AVSResult.new(code: response["avs_response"]),
          :cvv_result => CVVResult.new(response["cvv2_response"]),
          test: test?
        )

      rescue JSON::ParserError
        unparsable_response(raw_response)
      end

      def url
        test? ? test_url : live_url
      end

      def success_from(response)
        response["transaction_approved"] || !response["error"]
      end

      def message_from(response)
        success_from(response) ? response["authorization_message"] : response["error_message"]
      end

      def post_data(action, params)
        params[:transaction_type] = action
        params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from PayConex. Please contact PayConex if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

    end
  end
end
