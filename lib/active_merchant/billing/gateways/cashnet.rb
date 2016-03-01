module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CashnetGateway < Gateway
      include Empty

      self.live_url      = "https://commerce.cashnet.com/"

      self.supported_countries = ["US"]
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url        = "http://www.higherone.com/"
      self.display_name        = "Cashnet"
      self.money_format        = :dollars

      # Creates a new CashnetGateway
      #
      # ==== Options
      #
      # * <tt>:merchant</tt> -- Gateway Merchant (REQUIRED)
      # * <tt>:operator</tt> -- Operator (REQUIRED)
      # * <tt>:password</tt> -- Password (REQUIRED)
      # * <tt>:merchant_gateway_name</tt> -- Site name (REQUIRED)
      # * <tt>:station</tt> -- Station (defaults to "WEB")
      # * <tt>:custcode</tt> -- Customer code (defaults to
      #   "ActiveMerchant/#{ActiveMerchant::VERSION}")
      # * <tt>:default_item_code</tt> -- Default item code (defaults to "FEE",
      #   can be overridden on a per-transaction basis with options[:item_code])
      def initialize(options = {})
        requires!(
          options,
          :merchant,
          :operator,
          :password,
          :merchant_gateway_name
        )
        options[:default_item_code] ||= "FEE"
        super
      end

      def purchase(money, payment_object, options = {})
        post = {}
        add_creditcard(post, payment_object)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit('SALE', money, post)
      end

      def refund(money, identification, options = {})
        post = {}
        post[:origtx]  = identification
        add_invoice(post, options)
        add_customer_data(post, options)
        commit('REFUND', money, post)
      end

      private

      def commit(action, money, fields)
        fields[:amount] = amount(money)
        url = live_url + CGI.escape(@options[:merchant_gateway_name])
        raw_response = ssl_post(url, post_data(action, fields))
        parsed_response = parse(raw_response)

        return unparsable_response(raw_response) unless parsed_response

        success = (parsed_response[:result] == '0')
        Response.new(
          success,
          CASHNET_CODES[parsed_response[:result]],
          parsed_response,
          test:          test?,
          authorization: (success ? parsed_response[:tx] : '')
        )
      end

      def post_data(action, parameters = {})
        post = {}
        post[:command]        = action
        post[:merchant]       = @options[:merchant]
        post[:operator]       = @options[:operator]
        post[:password]       = @options[:password]
        post[:station]        = (@options[:station] || "WEB")
        post[:custcode]       = (@options[:custcode] || "ActiveMerchant/#{ActiveMerchant::VERSION}")
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_creditcard(post, creditcard)
        post[:cardno]          = creditcard.number
        post[:cid]             = creditcard.verification_value
        post[:expdate]         = expdate(creditcard)
        post[:card_name_g]     = creditcard.name
        post[:fname]           = creditcard.first_name
        post[:lname]           = creditcard.last_name
      end

      def add_invoice(post, options)
        post[:order_number]    = options[:order_id] if options[:order_id].present?
        post[:itemcode]       = (options[:item_code] || @options[:default_item_code])
      end

      def add_address(post, options)
        if address = (options[:shipping_address] || options[:billing_address] || options[:address])
          post[:addr_g]       = String(address[:address1]) + ',' + String(address[:address2])
          post[:city_g]       = address[:city]
          post[:state_g]      = address[:state]
          post[:zip_g]        = address[:zip]
        end
      end

      def add_customer_data(post, options)
        post[:email_g]  = options[:email]
        post[:custcode]  = options[:custcode] unless empty?(options[:custcode])
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def parse(body)
        match = body.match(/<cngateway>(.*)<\/cngateway>/)
        return nil unless match

        Hash[CGI::parse(match[1]).map{|k,v| [k.to_sym,v.first]}]
      end

      def handle_response(response)
        if (200...300).include?(response.code.to_i)
          return response.body
        elsif 302 == response.code.to_i
          return ssl_get(URI.parse(response['location']))
        end
        raise ResponseError.new(response)
      end

      def unparsable_response(raw_response)
        message = "Unparsable response received from Cashnet. Please contact Cashnet if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      CASHNET_CODES = {
        '0' => 'Success',
        '1' => 'Invalid customer code, no customer code specified',
        '2' => 'Invalid operator code, no operator specified',
        '3' => 'Invalid workstation code, no station specified',
        '4' => 'Invalid item code, no code specified',
        '5' => 'Negative amount is not allowed',
        '6' => 'Invalid credit card number, no credit card number provided',
        '7' => 'Invalid expiration date, no expiration date provided',
        '8' => 'Please only provide either ACH or credit card information',
        '9' => 'Invalid ACH account number, no account number provided',
        '10' => 'Invalid routing/transit number, no routing/transit number provided',
        '11' => 'Invalid account type, no account type provided',
        '12' => 'Invalid check digit for routing/transit number',
        '13' => 'No ACH merchant account set up for the location of the station being used',
        '21' => 'Invalid merchant code, no merchant code provided',
        '22' => 'Invalid client code, no client code provided',
        '23' => 'Invalid password, no password provided',
        '24' => 'Invalid transaction type, no transaction type provided',
        '25' => 'Invalid amount, amount not provided',
        '26' => 'Invalid payment code provided',
        '27' => 'Invalid version number, version not found',
        '31' => 'Application amount exceeds account balance',
        '150' => 'Invalid payment information, no payment information provided',
        '200' => 'Invalid command',
        '201' => 'Customer not on file',
        '205' => 'Invalid operator or password',
        '206' => 'Operator is not authorized for this function',
        '208' => 'Customer/PIN authentication unsuccessful',
        '209' => 'Credit card error',
        '211' => 'Credit card error',
        '212' => 'Customer/PIN not on file',
        '213' => 'Customer information not on file',
        '215' => 'Old PIN does not validate ',
        '221' => 'Invalid credit card processor type specified in location or payment code',
        '222' => 'Credit card processor error',
        '280' => 'SmartPay transaction not posted',
        '301' => 'Original transaction not found for this customer',
        '302' => 'Amount to refund exceeds original payment amount or is missing',
        '304' => 'Original credit card payment not found or corrupted',
        '305' => 'Refund amounts should be expressed as positive amounts',
        '306' => 'Original ACH payment not found',
        '307' => 'Original electronic payment not found',
        '308' => 'Invalid original transaction number, original transaction number not found',
        '310' => 'Refund amount exceeds amount still available for a refund',
        '321' => 'Store has not been implemented',
        '501' => 'Unable to roll over batch',
        '502' => 'Batch not found',
        '503' => 'Batch information not available',
        '650' => 'Invalid quick code',
        '651' => 'Transaction amount does not match amount specified in quick code',
        '652' => 'Invalid item code in the detail of the quick code',
        '701' => 'This website has been disabled. Please contact the system administrator.',
        '702' => 'Improper merchant code. Please contact the system administrator.',
        '703' => 'This site is temporarily down for maintenance. We regret the inconvenience. Please try again later.',
        '704' => 'Duplicate item violation. Please contact the system administrator.',
        '705' => 'An invalid reference type has been passed into the system. Please contact the system administrator',
        '706' => 'Items violating unique selection have been passed in. Please contact the system administrator.',
        '999' => 'An unexpected error has occurred. Please consult the event log.'
      }
    end
  end
end
