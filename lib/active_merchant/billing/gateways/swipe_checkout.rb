require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SwipeCheckoutGateway < Gateway
      TRANSACTION_APPROVED_MSG = 'Transaction approved'
      TRANSACTION_DECLINED_MSG = 'Transaction declined'

      LIVE_URLS = {
        'NZ' => 'https://api.swipehq.com',
        'CA' => 'https://api.swipehq.ca'
      }
      self.test_url = 'https://api.swipehq.com'

      TRANSACTION_API = '/createShopifyTransaction.php'

      self.supported_countries = %w[ NZ CA ]
      self.default_currency = 'NZD'
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'https://www.swipehq.com/checkout'
      self.display_name = 'Swipe Checkout'
      self.money_format = :dollars

      # Swipe Checkout requires the merchant's email and API key for authorization.
      # This can be found under Settings > API Credentials after logging in to your
      # Swipe Checkout merchant console at https://merchant.swipehq.[com|ca]
      #
      # :region determines which Swipe URL is used, this can be one of "NZ" or "CA".
      # Currently Swipe Checkout has New Zealand and Canadian domains (swipehq.com
      # and swipehq.ca respectively). Merchants must use the region that they
      # signed up in for authentication with their merchant ID and API key to succeed.
      def initialize(options = {})
        requires!(options, :login, :api_key, :region)
        super
      end

      # Transfers funds immediately.
      # Note that Swipe Checkout only supports purchase at this stage
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, creditcard, options)
        add_amount(post, money, options)

        commit('sale', money, post)
      end

      private

      def add_customer_data(post, creditcard, options)
        post[:email] = options[:email]
        post[:ip_address] = options[:ip]

        address = options[:billing_address] || options[:address]
        return if address.nil?

        post[:company] = address[:company]

        # groups all names after the first into the last name param
        post[:first_name], post[:last_name] = address[:name].split(' ', 2)
        post[:address] = "#{address[:address1]}, #{address[:address2]}"
        post[:city] = address[:city]
        post[:country] = address[:country]
        post[:mobile] = address[:phone]     # API only has a "mobile" field, no "phone"
      end

      def add_invoice(post, options)
        # store shopping-cart order ID in Swipe for merchant's records
        post[:td_user_data] = options[:order_id] if options[:order_id]
        post[:td_item] = options[:description] if options[:description]
        post[:td_description] = options[:description] if options[:description]
        post[:item_quantity] = "1"
      end

      def add_creditcard(post, creditcard)
        post[:card_number] = creditcard.number
        post[:card_type] = creditcard.brand
        post[:name_on_card] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:card_expiry] = expdate(creditcard)
        post[:secure_number] = creditcard.verification_value
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def add_amount(post, money, options)
        post[:amount] = money.to_s

        post[:currency] = (options[:currency] || currency(money))
      end

      def commit(action, money, parameters)
        case action
        when "sale"
          begin
            response = call_api(TRANSACTION_API, parameters)

            # response code and message params should always be present
            code = response["response_code"]
            message = response["message"]

            if code == 200
              result = response["data"]["result"]
              success = (result == 'accepted' || (test? && result == 'test-accepted'))

              Response.new(success,
                success ?
                TRANSACTION_APPROVED_MSG :
                TRANSACTION_DECLINED_MSG,
                response,
                :test => test?
              )
            else
              build_error_response(message, response)
            end
          rescue ResponseError => e
            build_error_response("ssl_post() with url #{url} raised ResponseError: #{e}")
          rescue JSON::ParserError => e
            msg = 'Invalid response received from the Swipe Checkout API. ' +
                  'Please contact support@optimizerhq.com if you continue to receive this message.' +
                  " (Full error message: #{e})"
            build_error_response(msg)
          end
        end
      end

      def call_api(api, params=nil)
        params ||= {}
        params[:merchant_id] = @options[:login]
        params[:api_key] = @options[:api_key]

        # ssl_post() returns the response body as a string on success,
        # or raises a ResponseError exception on failure
        JSON.parse(ssl_post(url(@options[:region], api), params.to_query))
      end

      def url(region, api)
        ((test? ? self.test_url : LIVE_URLS[region]) + api)
      end

      def build_error_response(message, params={})
        Response.new(
          false,
          message,
          params,
          :test => test?
        )
      end
    end
  end
end

