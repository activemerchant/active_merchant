require 'nokogiri'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    #
    # == Monei gateway
    # This class implements Monei gateway for Active Merchant. For more information about Monei
    # gateway please go to http://www.monei.com
    #
    # === Setup
    # In order to set-up the gateway you need only one paramater: the api_key
    # Request that data to Monei.
    class MoneiGateway < Gateway
      self.live_url = self.test_url = 'https://api.monei.com/v1/payments'

      self.supported_countries = %w[AD AT BE BG CA CH CY CZ DE DK EE ES FI FO FR GB GI GR HU IE IL IS IT LI LT LU LV MT NL NO PL PT RO SE SI SK TR US VA]
      self.default_currency = 'EUR'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master maestro jcb american_express]

      self.homepage_url = 'https://monei.com/'
      self.display_name = 'MONEI'

      # Constructor
      #
      # options - Hash containing the gateway credentials, ALL MANDATORY
      #           :api_key      Account's API KEY
      #
      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      # Public: Performs purchase operation
      #
      # money       - Amount of purchase
      # payment_method - Credit card
      # options     - Hash containing purchase options
      #               :order_id         Merchant created id for the purchase
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created purchase description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object
      def purchase(money, payment_method, options = {})
        execute_new_order(:purchase, money, payment_method, options)
      end

      # Public: Performs authorization operation
      #
      # money       - Amount to authorize
      # payment_method - Credit card
      # options     - Hash containing authorization options
      #               :order_id         Merchant created id for the authorization
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created authorization description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object
      def authorize(money, payment_method, options = {})
        execute_new_order(:authorize, money, payment_method, options)
      end

      # Public: Performs capture operation on previous authorization
      #
      # money         - Amount to capture
      # authorization - Reference to previous authorization, obtained from response object returned by authorize
      # options       - Hash containing capture options
      #                 :order_id         Merchant created id for the authorization (optional)
      #                 :description      Merchant created authorization description (optional)
      #                 :currency         Sale currency to override money object or default (optional)
      #
      # Note: you should pass either order_id or description
      #
      # Returns Active Merchant response object
      def capture(money, authorization, options = {})
        execute_dependant(:capture, money, authorization, options)
      end

      # Public: Refunds from previous purchase
      #
      # money         - Amount to refund
      # authorization - Reference to previous purchase, obtained from response object returned by purchase
      # options       - Hash containing refund options
      #                 :order_id         Merchant created id for the authorization (optional)
      #                 :description      Merchant created authorization description (optional)
      #                 :currency         Sale currency to override money object or default (optional)
      #
      # Note: you should pass either order_id or description
      #
      # Returns Active Merchant response object
      def refund(money, authorization, options = {})
        execute_dependant(:refund, money, authorization, options)
      end

      # Public: Voids previous authorization
      #
      # authorization - Reference to previous authorization, obtained from response object returned by authorize
      # options       - Hash containing capture options
      #                 :order_id         Merchant created id for the authorization (optional)
      #
      # Returns Active Merchant response object
      def void(authorization, options = {})
        execute_dependant(:void, nil, authorization, options)
      end

      # Public: Verifies credit card. Does this by doing a authorization of 1.00 Euro and then voiding it.
      #
      # payment_method - Credit card
      # options     - Hash containing authorization options
      #               :order_id         Merchant created id for the authorization
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created authorization description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object of Authorization operation
      def verify(payment_method, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        execute_new_order(:store, 0, payment_method, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: )\w+), '\1[FILTERED]').
          gsub(%r(("number\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvc\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cavv\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      # Private: Execute purchase or authorize operation
      def execute_new_order(action, money, payment_method, options)
        request = build_request
        add_identification_new_order(request, options)
        add_transaction(request, action, money, options)
        add_payment(request, payment_method)
        add_customer(request, payment_method, options)
        add_3ds_authenticated_data(request, options)
        add_browser_info(request, options)
        commit(request, action, options)
      end

      # Private: Execute operation that depends on authorization code from previous purchase or authorize operation
      def execute_dependant(action, money, authorization, options)
        request = build_request

        add_identification_authorization(request, authorization, options)
        add_transaction(request, action, money, options)

        commit(request, action, options)
      end

      # Private: Build request object
      def build_request
        request = {}
        request[:livemode] = test? ? 'false' : 'true'
        request
      end

      # Private: Add identification part to request for new orders
      def add_identification_new_order(request, options)
        requires!(options, :order_id)
        request[:orderId] = options[:order_id]
      end

      # Private: Add identification part to request for orders that depend on authorization from previous operation
      def add_identification_authorization(request, authorization, options)
        options[:paymentId] = authorization
        request[:orderId] = options[:order_id] if options[:order_id]
      end

      # Private: Add payment part to request
      def add_transaction(request, action, money, options)
        request[:transactionType] = translate_payment_code(action)
        request[:description] = options[:description] || options[:order_id]
        unless money.nil?
          request[:amount] = amount(money).to_i
          request[:currency] = options[:currency] || currency(money)
        end
      end

      # Private: Add payment method to request
      def add_payment(request, payment_method)
        if payment_method.is_a? String
          request[:paymentToken] = payment_method
        else
          request[:paymentMethod] = {}
          request[:paymentMethod][:card] = {}
          request[:paymentMethod][:card][:number] = payment_method.number
          request[:paymentMethod][:card][:expMonth] = format(payment_method.month, :two_digits)
          request[:paymentMethod][:card][:expYear] = format(payment_method.year, :two_digits)
          request[:paymentMethod][:card][:cvc] = payment_method.verification_value.to_s
          request[:paymentMethod][:card][:cardholderName] = payment_method.name
        end
      end

      # Private: Add customer part to request
      def add_customer(request, payment_method, options)
        address = options[:billing_address] || options[:address]

        request[:customer] = {}
        request[:customer][:email] = options[:email] || 'support@monei.net'

        if address
          request[:customer][:name] = address[:name].to_s if address[:name]

          request[:billingDetails] = {}
          request[:billingDetails][:email] = options[:email] if options[:email]
          request[:billingDetails][:name] = address[:name] if address[:name]
          request[:billingDetails][:company] = address[:company] if address[:company]
          request[:billingDetails][:phone] = address[:phone] if address[:phone]
          request[:billingDetails][:address] = {}
          request[:billingDetails][:address][:line1] = address[:address1] if address[:address1]
          request[:billingDetails][:address][:line2] = address[:address2] if address[:address2]
          request[:billingDetails][:address][:city] = address[:city] if address[:city]
          request[:billingDetails][:address][:state] = address[:state] if address[:state].present?
          request[:billingDetails][:address][:zip] = address[:zip].to_s if address[:zip]
          request[:billingDetails][:address][:country] = address[:country] if address[:country]
        end

        request[:sessionDetails] = {}
        request[:sessionDetails][:ip] = options[:ip] if options[:ip]
      end

      # Private : Convert ECI to ResultIndicator
      # Possible ECI values:
      # 02 or 05 - Fully Authenticated Transaction
      # 00 or 07 - Non 3D Secure Transaction
      # Possible ResultIndicator values:
      # 01 = MASTER_3D_ATTEMPT
      # 02 = MASTER_3D_SUCCESS
      # 05 = VISA_3D_SUCCESS
      # 06 = VISA_3D_ATTEMPT
      # 07 = DEFAULT_E_COMMERCE
      def eci_to_result_indicator(eci)
        case eci
        when '02', '05'
          return eci
        else
          return '07'
        end
      end

      # Private: add the already validated 3DSecure info to request
      def add_3ds_authenticated_data(request, options)
        if options[:three_d_secure] && options[:three_d_secure][:eci] && options[:three_d_secure][:xid]
          add_3ds1_authenticated_data(request, options)
        elsif options[:three_d_secure]
          add_3ds2_authenticated_data(request, options)
        end
      end

      def add_3ds1_authenticated_data(request, options)
        three_d_secure_options = options[:three_d_secure]
        request[:paymentMethod][:card][:auth] = {
          cavv: three_d_secure_options[:cavv],
          cavvAlgorithm: three_d_secure_options[:cavv_algorithm],
          eci: three_d_secure_options[:eci],
          xid: three_d_secure_options[:xid],
          directoryResponse: three_d_secure_options[:enrolled],
          authenticationResponse: three_d_secure_options[:authentication_response_status]
        }
      end

      def add_3ds2_authenticated_data(request, options)
        three_d_secure_options = options[:three_d_secure]
        # If the transaction was authenticated in a frictionless flow, send the transStatus from the ARes.
        if three_d_secure_options[:authentication_response_status].nil?
          authentication_response = three_d_secure_options[:directory_response_status]
        else
          authentication_response = three_d_secure_options[:authentication_response_status]
        end
        request[:paymentMethod][:card][:auth] = {
          threeDSVersion: three_d_secure_options[:version],
          eci: three_d_secure_options[:eci],
          cavv: three_d_secure_options[:cavv],
          dsTransID: three_d_secure_options[:ds_transaction_id],
          directoryResponse: three_d_secure_options[:directory_response_status],
          authenticationResponse: authentication_response
        }
      end

      def add_browser_info(request, options)
        request[:sessionDetails][:ip] = options[:ip] if options[:ip]
        request[:sessionDetails][:userAgent] = options[:user_agent] if options[:user_agent]
        request[:sessionDetails][:lang] = options[:lang] if options[:lang]
      end

      # Private: Parse JSON response from Monei servers
      def parse(body)
        JSON.parse(body)
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the MONEI API. Please contact support@monei.net if you continue to receive this message.'
        msg += " (The raw response returned by the API was #{raw_response.inspect})"
        {
          'status' => 'error',
          'message' => msg
        }
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def api_request(url, parameters, options = {})
        raw_response = response = nil
        begin
          raw_response = ssl_post(url, post_data(parameters), options)
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      # Private: Send transaction to Monei servers and create AM response
      def commit(request, action, options)
        url = (test? ? test_url : live_url)
        endpoint = translate_action_endpoint(action, options)
        headers = {
          'Content-Type': 'application/json;charset=UTF-8',
          Authorization: @options[:api_key],
          'User-Agent': 'MONEI/Shopify/0.1.0'
        }

        response = api_request(url + endpoint, params(request, action), headers)
        success = success_from(response)

        Response.new(
          success,
          message_from(response, success),
          response,
          authorization: authorization_from(response, action),
          test: test?,
          error_code: error_code_from(response, success)
        )
      end

      # Private: Decide success from servers response
      def success_from(response)
        %w[
          SUCCEEDED
          AUTHORIZED
          REFUNDED
          PARTIALLY_REFUNDED
          CANCELED
        ].include? response['status']
      end

      # Private: Get message from servers response
      def message_from(response, success)
        success ? 'Transaction approved' : response.fetch('statusMessage', response.fetch('message', 'No error details'))
      end

      # Private: Get error code from servers response
      def error_code_from(response, success)
        success ? nil : STANDARD_ERROR_CODE[:card_declined]
      end

      # Private: Get authorization code from servers response
      def authorization_from(response, action)
        case action
        when :store
          return response['paymentToken']
        else
          return response['id']
        end
      end

      # Private: Encode POST parameters
      def post_data(params)
        params.clone.to_json
      end

      # Private: generate request params depending on action
      def params(request, action)
        request[:generatePaymentToken] = true if action == :store
        request
      end

      # Private: Translate AM operations to Monei operations codes
      def translate_payment_code(action)
        {
          purchase: 'SALE',
          store: 'SALE',
          authorize: 'AUTH',
          capture: 'CAPTURE',
          refund: 'REFUND',
          void: 'CANCEL'
        }[action]
      end

      # Private: Translate AM operations to Monei endpoints
      def translate_action_endpoint(action, options)
        {
          purchase: '',
          store: '',
          authorize: '',
          capture: "/#{options[:paymentId]}/capture",
          refund: "/#{options[:paymentId]}/refund",
          void: "/#{options[:paymentId]}/cancel"
        }[action]
      end
    end
  end
end
