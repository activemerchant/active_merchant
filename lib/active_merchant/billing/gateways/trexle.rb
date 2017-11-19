module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TrexleGateway < Gateway
      self.test_url = 'https://core.trexle.com/api/v1'
      self.live_url = 'https://core.trexle.com/api/v1'

      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_countries = %w(AD AE AT AU BD BE BG BN CA CH CY CZ DE DK EE EG ES FI FR GB
                                    GI GR HK HU ID IE IL IM IN IS IT JO KW LB LI LK LT LU LV MC
                                    MT MU MV MX MY NL NO NZ OM PH PL PT QA RO SA SE SG SI SK SM
                                    TR TT UM US VA VN ZA)
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'https://trexle.com'
      self.display_name = 'Trexle'

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      # Create a charge using a credit card, card token or customer token
      #
      # To charge a credit card: purchase([money], [creditcard hash], ...)
      # To charge a customer: purchase([money], [token], ...)
      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        commit(:post, 'charges', post, options)
      end

      # Create a customer and associated credit card. The token that is returned
      # can be used instead of a credit card parameter in the purchase method
      def store(creditcard, options = {})
        post = {}

        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_address(post, creditcard, options)
        commit(:post, 'customers', post, options)
      end

      # Refund a transaction
      def refund(money, token, options = {})
        commit(:post, "charges/#{CGI.escape(token)}/refunds", { amount: amount(money) }, options)
      end

      # Authorize an amount on a credit card. Once authorized, you can later
      # capture this charge using the charge token that is returned.
      def authorize(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        post[:capture] = false
        commit(:post, 'charges', post, options)
      end

      # Captures a previously authorized charge. Capturing only part of the original
      # authorization is currently not supported.
      def capture(money, token, options = {})
        commit(:put, "charges/#{CGI.escape(token)}/capture", { amount: amount(money) }, options)
      end

      # Updates the credit card for the customer.
      def update(token, creditcard, options = {})
        post = {}

        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_address(post, creditcard, options)
        commit(:put, "customers/#{CGI.escape(token)}", post, options)
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(/(number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(cvc\\?":\\?")(\d*)/, '\1[FILTERED]')
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

      def add_address(post, creditcard, options)
        return if creditcard.kind_of?(String)
        address = (options[:billing_address] || options[:address])
        return unless address

        post[:card] ||= {}
        post[:card].merge!(
          address_line1: address[:address1],
          address_line2: address[:address_line2],
          address_city: address[:city],
          address_postcode: address[:zip],
          address_state: address[:state],
          address_country: address[:country]
        )
      end

      def add_invoice(post, options)
        post[:description] = options[:description] || "Active Merchant Purchase"
      end

      def add_creditcard(post, creditcard)
        if creditcard.respond_to?(:number)
          post[:card] ||= {}

          post[:card].merge!(
            number: creditcard.number,
            expiry_month: creditcard.month,
            expiry_year: creditcard.year,
            cvc: creditcard.verification_value,
            name: creditcard.name
          )
        elsif creditcard.kind_of?(String)
          if creditcard =~ /^token_/
            post[:card_token] = creditcard
          else
            post[:customer_token] = creditcard
          end
        end
      end

      def headers(params = {})
        result = {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode64(options[:api_key] + ':').strip}"
        }

        result['X-Partner-Key'] = params[:partner_key] if params[:partner_key]
        result['X-Safe-Card'] = params[:safe_card] if params[:safe_card]
        result
      end
      
      def commit(method, action, params, options)
        url = "#{test? ? test_url : live_url}/#{action}"
        raw_response = ssl_request(method, url, post_data(params), headers(options))
        parsed_response = parse(raw_response)
        success_response(parsed_response) 
      rescue ResponseError => e
        error_response(parse(e.response.body))
      rescue JSON::ParserError
        unparsable_response(raw_response)
      end
  
      def success_response(body)
        return invalid_response unless body['response']
      
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
        return invalid_response unless body['error']
        Response.new(
          false,
          body['error'],
          body,
          authorization: nil,
          test: test?
        )
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from Trexle. Please contact support@trexle.com if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end
      
      def invalid_response
        message = "Invalid response."
        return Response.new(false, message)
      end

      def token(response)
        response['token']
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body) 
      end

      def post_data(parameters = {})
        parameters.to_json
      end
    end
  end
end
