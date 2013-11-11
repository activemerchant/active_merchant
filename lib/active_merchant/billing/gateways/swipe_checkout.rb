require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Swipe Checkout is an e-commerce gateway currently available to New Zealand and
    # Canadian customers merchants.
    # For more information please visit https://www.swipehq.com
    class SwipeCheckoutGateway < Gateway
      TRANSACTION_APPROVED_MSG = 'Transaction approved'
      TRANSACTION_DECLINED_MSG = 'Transaction declined'

      # Swipe Checkout live URL by region
      LIVE_URLS = {
        'NZ' => 'https://api.swipehq.com',
        'CA' => 'https://api.swipehq.ca'
      }

      self.test_url = 'https://api.swipehq.com'

      TRANSACTION_API = '/createShopifyTransaction.php'

      # This API is used to find the currencies a merchant can accept payments in,
      # which depends on the underlying gateway/bank they're using in their region.
      # In NZ, the only underlying gateway currently available is BNZ which supports
      # AUD CAD CNY EUR GBP HKD JPY KRW NZD SGD USD ZAR.
      # In Canada merchants can choose between multiple back-end gateways so the
      # set of available currencies can vary (hence the need for this API).
      CURRENCIES_API = '/fetchCurrencyCodes.php'

      # The countries the gateway supports merchants from as 2 digit ISO country codes.
      # Swipe Checkout currently allows merchant signups from New Zealand and Canada.
      self.supported_countries = %w[ NZ CA ]

      self.default_currency = 'NZD'

      # Swipe Checkout supports Visa and Mastercard
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

      # ======================================================================
      private

      # add any customer details to the request
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

      # add any details about the product or service being paid for
      def add_invoice(post, options)
        # store shopping-cart order ID in Swipe for merchant's records
        post[:td_user_data] = options[:order_id] if options[:order_id]
        post[:td_item] = options[:description] if options[:description]
        post[:td_description] = options[:description] if options[:description]
        post[:item_quantity] = "1"
      end

      # add credit card no, expiry, CVV, ...
      def add_creditcard(post, creditcard)
        post[:card_number] = creditcard.number
        post[:card_type] = creditcard.brand
        post[:name_on_card] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:card_expiry] = expdate(creditcard)
        post[:secure_number] = creditcard.verification_value
      end

      # Formats expiry dates as MMDD (source: blue_pay.rb)
      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def add_amount(post, money, options)
        post[:amount] = money.to_s
        
        # Assuming ISO_3166-1 (3 character) currency code
        post[:currency] = options[:currency] || currency(money)
      end

      def commit(action, money, parameters)
        case action
        when "sale"

          begin
            # ensure incoming currency is supported by merchant's selected gateway
            currency = parameters[:currency]
            result, error_message = supported_currency? currency
            if !result
              return build_error_response(error_message)
            end
            
            # gets hash of JSON response data
            response = call_api TRANSACTION_API, parameters

            # response code and message params should always be present
            code = response["response_code"]
            message = response["message"]

            if code == 200  # OK
              result = response["data"]["result"]
              success = result == 'accepted' || (test? && result == 'test-accepted')

              Response.new(success,
                           success ?
                           TRANSACTION_APPROVED_MSG :
                           TRANSACTION_DECLINED_MSG,
                           response,
                           :test => test?)
            else
              build_error_response(message, response)
            end
          rescue ResponseError => e
            raw_response = e.response.body
            build_error_response("ssl_post() with url #{url} raised ResponseError: #{e}")
          rescue JSON::ParserError => e
            msg = 'Invalid response received from the Swipe Checkout API. ' +
                  'Please contact support@optimizerhq.com if you continue to receive this message.' +
                  " (Full error message: #{e})"
            build_error_response(msg)
          end
        end
      end

      # Convenience function - returns the parsed JSON response from an API call as a hash
      def call_api(api, params=nil)
        if !params then params = {} end
        params[:merchant_id] = @options[:login]
        params[:api_key] = @options[:api_key]
        region = @options[:region]
        url = get_base_url(region) + api

        #puts "#{url}?#{params.to_query}"

        # ssl_post() returns the response body as a string on success,
        # or raises a ResponseError exception on failure
        parse( ssl_post( url, params.to_query ) )
      end

      def parse(body)
        JSON.parse(body)
      end

      def get_base_url(region)
        (test?) ? self.test_url : LIVE_URLS[region]
      end

      # Returns whether a currency is valid for this merchant.
      # Currency should be in ISO 3166-1 (3 character) format
      # e.g. AUD, JPY
      def supported_currency?(currency)
        response = call_api CURRENCIES_API
        code = response["response_code"]
        message = response["message"]

        if code == 200  # OK
          supported_currencies = response['data'].values
          if !supported_currencies.include? currency
            [false, "Unsupported currency \"#{currency}\""]
          else
            [true, "OK"]
          end
        else
          [false, message]
        end
      end

      def build_error_response(message, params={})
        Response.new(false,
                     message,
                     params,
                     :test => test?)
      end
    end
  end
end

