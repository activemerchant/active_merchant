module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CashnetGateway < Gateway
      class_attribute :ignore_http_status

      self.live_url      = 'https://commerce.cashnet.com/cashnete/Gateway/htmlgw.aspx'
      self.ignore_http_status = true

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url        = 'http://www.higherone.com/'
      self.display_name        = 'Cashnet'
      self.money_format        = :dollars

      # Creates a new CashnetGateway
      #
      # ==== Options
      #
      # * <tt>:merchant_name</tt> -- The Gateway Merchant Name (REQUIRED)
      # * <tt>:station</tt> -- Station (REQUIRED)
      # * <tt>:operator</tt> -- Operator (REQUIRED)
      # * <tt>:password</tt> -- Password (REQUIRED)
      # * <tt>:credit_card_payment_code </tt> -- Credit Card Payment Code  (REQUIRED)
      # * <tt>:customer_code</tt> -- Customer Code (REQUIRED)
      # * <tt>:item_code</tt> -- Item code (REQUIRED)
      # * <tt>:merchant_gateway_name</tt> -- Site name (REQUIRED)
      # * <tt>:test</tt> -- set to true for TEST mode or false for LIVE mode
      def initialize(options = {})
        requires!(options, :merchant_name, :station, :operator,
          :password, :credit_card_payment_code, :customer_code, :item_code, :merchant_gateway_name)
        super
      end

      def purchase(money, payment_object, fields = {})
        post = {}
        add_creditcard(post, payment_object)
        add_invoice(post, fields)
        add_address(post, fields)
        add_customer_data(post, fields)
        commit('SALE', money, post)
      end

      def refund(money, identification, fields = {})
        fields[:origtx]  = identification
        commit('REFUND', money, fields)
      end

      private

      def commit(action, money, fields)
        fields[:amount] = amount(money) 
        url = live_url 
        fields[:client] = @options[:merchant_gateway_name]
        parse(ssl_post(url, post_data(action, fields)))
      end

      def post_data(action, parameters = {})
        post = {}
        post[:command]        = action
        post[:merchant]       = @options[:merchant_name]
        post[:operator]       = @options[:operator]
        post[:station]        = @options[:station]
        post[:password]       = @options[:password]
        post[:custcode]       = @options[:customer_code]
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_creditcard(post, creditcard)
        post[:cardno]          = creditcard.number
        post[:cid]             = creditcard.verification_value
        post[:expdate]         = expdate(creditcard)
        post[:card_name_g]     = creditcard.name
      end

      def add_invoice(post, options)
        post[:order_number]    = options[:order_id] if options[:order_id].present?
        post[:itemcode]        = @options[:item_code]
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
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def parse(body)
        puts body.inspect
        response_data = body.match(/<cngateway>(.*)<\/cngateway>/)[1]
        response_fields = Hash[CGI::parse(response_data).map{|k,v| [k.to_sym,v.first]}]

        # normalize message
        message = CASHNET_CODES[response_fields[:result]]
        success = response_fields[:result] == '0'
        Response.new(success, message, response_fields,
          :test          => test?,
          :authorization => success ? response_fields[:txno] : ''
        )
      end

      def handle_response(response)
        if ignore_http_status || (200...300).include?(response.code.to_i)
          return response.body
        end
        raise ResponseError.new(response)
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