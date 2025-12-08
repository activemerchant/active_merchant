module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class PinGateway < Gateway
      version '1'

      self.test_url = "https://test-api.pinpayments.com/#{fetch_version}"
      self.live_url = "https://api.pinpayments.com/#{fetch_version}"

      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_countries = %w(AU NZ)
      self.supported_cardtypes = %i[visa master american_express diners_club discover jcb]
      self.homepage_url = 'http://www.pinpayments.com/'
      self.display_name = 'Pin Payments'

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      # Create a charge using a payment method, card token or customer token
      #
      # To charge a payment method: purchase([money], [payment_method hash], ...)
      # To charge a customer: purchase([money], [token], ...)
      def purchase(money, payment_method, options = {})
        post = {}

        add_amount(post, money, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method)
        add_address(post, payment_method, options)
        add_capture(post, options)
        add_metadata(post, options)
        add_3ds(post, options)
        add_platform_adjustment(post, options)

        commit(:post, 'charges', post, options)
      end

      # Create a customer and associated payment method. The token that is returned
      # can be used instead of a payment method parameter in the purchase method
      def store(payment_method, options = {})
        post = {}

        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_address(post, payment_method, options)
        commit(:post, 'customers', post, options)
      end

      # Unstore a customer and associated payment method.
      def unstore(token)
        customer_token =
          if /cus_/.match?(token)
            get_customer_token(token)
          else
            token
          end
        commit(:delete, "customers/#{CGI.escape(customer_token)}", {}, {})
      end

      # Refund a transaction
      def refund(money, token, options = {})
        commit(:post, "charges/#{CGI.escape(token)}/refunds", { amount: amount(money) }, options)
      end

      # Authorize an amount on a payment method. Once authorized, you can later
      # capture this charge using the charge token that is returned.
      def authorize(money, payment_method, options = {})
        options[:capture] = false

        purchase(money, payment_method, options)
      end

      # Captures a previously authorized charge. Capturing only part of the original
      # authorization is currently not supported.
      def capture(money, token, options = {})
        commit(:put, "charges/#{CGI.escape(token)}/capture", { amount: amount(money) }, options)
      end

      # Voids a previously authorized charge.
      def void(token, options = {})
        commit(:put, "charges/#{CGI.escape(token)}/void", {}, options)
      end

      # Returns the details of a charge
      def inquire(token, options = {})
        commit(:get, "charges/#{CGI.escape(token)}", nil, options)
      end

      # Returns a paginated list of charges matching the search criteria.
      # ==== Options:
      # * <tt>:query </tt> -- (Optional) Return only charges whose fields match the query. Fields covered include description, email, metadata, cardholder name, currency, amount (exact), charge token (exact), card token (exact), refund token (exact), and customer token (exact).
      # * <tt>:start_date </tt> -- (Optional) Return only charges created on or after this date (e.g. 2012/12/25).
      # * <tt>:end_date </tt> -- (Optional) Return only charges created before this date (e.g. 2013/12/25).
      # * <tt>:sort</tt> -- (Optional) The field used to sort the charges (created_at or amount). Default value is created_at.
      # * <tt>:direction </tt> -- (Optional) The direction in which to sort the charges (1 for ascending or -1 for descending). Default value is 1.
      #
      def transaction_search(options = {})
        params = {}
        params[:query] = options[:query] if options[:query]
        params[:start_date] = options[:start_date] if options[:start_date]
        params[:end_date] = options[:end_date] if options[:end_date]
        params[:sort] = options[:sort] if options[:sort]
        params[:direction] = options[:direction] if options[:direction]
        params[:page] = options[:page] if options[:page]

        action = 'charges/search'
        action += '?' + params.to_query unless params.empty?

        commit(:get, action, nil, options)
      end

      # Verify a previously authorized charge.
      def verify_3ds(session_token, options = {})
        commit(:get, "/charges/verify?session_token=#{session_token}", nil, options)
      end

      # Updates the payment method for the customer.
      def update(token, payment_method, options = {})
        post = {}
        token = get_customer_token(token)

        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_address(post, payment_method, options)
        commit(:put, "customers/#{CGI.escape(token)}", post, options)
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(/(number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(cvc\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(cryptogram\\?":\\?")(\w*)/, '\1[FILTERED]')
      end

      private

      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:currency] = post[:currency].upcase if post[:currency]
      end

      def add_customer_data(post, options)
        post[:email] = options[:email] if options[:email]
        post[:ip_address] = options[:ip] if options[:ip]
      end

      def add_address(post, payment_method, options)
        return if payment_method.kind_of?(String) || payment_method.kind_of?(NetworkTokenizationCreditCard)

        address = (options[:billing_address] || options[:address])
        return unless address

        post[:card] ||= {}
        post[:card].merge!(
          address_line1: address[:address1],
          address_city: address[:city],
          address_postcode: address[:zip],
          address_state: address[:state],
          address_country: address[:country]
        )
      end

      def add_invoice(post, options)
        post[:description] = options[:description] || 'Active Merchant Purchase'
        post[:reference] = options[:reference] if options[:reference]
      end

      def add_capture(post, options)
        capture = options[:capture]

        post[:capture] = capture != false
      end

      def add_payment_method(post, payment_method)
        return unless payment_method

        case payment_method
        when NetworkTokenizationCreditCard
          get_token = get_single_use_token(payment_method, options)
          post[:payment_source_token] = get_token.params.dig('response', 'token')
        when CreditCard
          post[:card] ||= {}
          post[:card].merge!(
            number: payment_method.number,
            expiry_month: payment_method.month,
            expiry_year: payment_method.year,
            cvc: payment_method.verification_value,
            name: payment_method.name
          )
        when String
          if /^card_/.match?(payment_method)
            post[:card_token] = get_card_token(payment_method)
          else
            post[:customer_token] = payment_method
          end
        else
          raise ArgumentError, "Invalid payment method type: #{payment_method.class}"
        end
      end

      # Get a single use token from Pin for NT based payment methods
      # This is used to create a charge using a network tokenized card
      def get_single_use_token(payment_method, options)
        post = {
          type: 'network_token',
          source: {
            number: payment_method.number,
            expiry_month: payment_method.month,
            expiry_year: payment_method.year,
            network_type: payment_method.source.to_s.gsub('_', ''),
            cryptogram: payment_method.payment_cryptogram,
            eci: payment_method.eci
          }
        }

        commit(:post, 'payment_sources', post, options)
      end

      def get_customer_token(token)
        token.split(/;(?=cus)/).last
      end

      def get_card_token(token)
        token.split(/;(?=cus)/).first
      end

      def add_metadata(post, options)
        post[:metadata] = options[:metadata] if options[:metadata]
      end

      def add_platform_adjustment(post, options)
        post[:platform_adjustment] = options[:platform_adjustment] if options[:platform_adjustment]
      end

      def add_3ds(post, options)
        if options[:three_d_secure]
          post[:three_d_secure] = {}
          if options[:three_d_secure][:enabled]
            post[:three_d_secure][:enabled] = true
            post[:three_d_secure][:fallback_ok] = options[:three_d_secure][:fallback_ok] unless options[:three_d_secure][:fallback_ok].nil?
            post[:three_d_secure][:callback_url] = options[:three_d_secure][:callback_url] if options[:three_d_secure][:callback_url]
          else
            post[:three_d_secure][:version] = options[:three_d_secure][:version] if options[:three_d_secure][:version]
            post[:three_d_secure][:eci] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
            post[:three_d_secure][:cavv] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
            post[:three_d_secure][:transaction_id] = options[:three_d_secure][:ds_transaction_id] || options[:three_d_secure][:xid]
          end
        end
      end

      def headers(params = {})
        result = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{Base64.strict_encode64(options[:api_key] + ':').strip}"
        }

        result['X-Partner-Key'] = params[:partner_key] if params[:partner_key]
        result['X-Safe-Card'] = params[:safe_card] if params[:safe_card]
        result
      end

      def commit(method, action, params, options)
        url = "#{test? ? test_url : live_url}/#{action}"

        begin
          raw_response = ssl_request(method, url, post_data(params), headers(options))
          body = parse(raw_response)
        rescue ResponseError => e
          body = parse(e.response.body)
        end

        if body.nil?
          no_content_response
        elsif body['response'].is_a?(Array)
          paginated_response(body)
        elsif body['response']
          success_response(body)
        elsif body['error']
          error_response(body)
        end
      rescue JSON::ParserError
        return unparsable_response(raw_response)
      end

      def success_response(body)
        response = body['response']
        Response.new(
          true,
          response['status_message'],
          body,
          authorization: token(response),
          test: test?
        )
      end

      def error_response(body)
        Response.new(
          false,
          body['error_description'],
          body,
          authorization: nil,
          test: test?
        )
      end

      def no_content_response
        Response.new(
          true,
          nil,
          {},
          test: test?
        )
      end

      def unparsable_response(raw_response)
        message = 'Invalid JSON response received from Pin Payments. Please contact support@pinpayments.com if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      def paginated_response(body)
        Response.new(
          true,
          'Search successful',
          body,
          test: test?
        )
      end

      def token(response)
        if response['token'].start_with?('cus')
          "#{response.dig('card', 'token')};#{response['token']}"
        else
          response['token']
        end
      end

      def parse(body)
        JSON.parse(body) unless body.nil? || body.length == 0
      end

      def post_data(parameters = {})
        return nil unless parameters

        parameters.to_json
      end
    end
  end
end
