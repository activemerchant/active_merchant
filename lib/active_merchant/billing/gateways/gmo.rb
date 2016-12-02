require 'digest'
require 'cgi'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GmoGateway < Gateway
      self.test_url = 'https://pt01.mul-pay.jp/payment/'
      self.live_url = 'https://p01.mul-pay.jp/payment/'
      self.homepage_url = 'http://www.gmo-pg.com/global'
      self.display_name = 'GMO'
      self.money_format = :cents
      self.default_currency = 'JPY'
      self.supported_countries = ['JP']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      DECLINED_CODES = [
        '42G020000',
        '42G030000',
        '42G040000',
        '42G050000',
        '42G550000'
      ]

      INVALID_CARD_CODES = [
        '42G120000',
        '42G220000',
        '42G300000',
        '42G420000',
        '42G440000',
        '42G030000',
        '42G540000',
        '42G560000',
        '42G600000',
        '42G610000',
        '42G650000',
        '42G830000',
        '42G950000',
        '42G960000',
        '42G970000',
        '42G980000',
        '42G990000'
      ]

      DUPLICATE_ORDER_CODE = 'E01040010'

      # The API does not return error messages, so I translated these from the
      # example english-like messages in the GMO documentation
      ERROR_CODES = {
        'E01010001' => 'Shop ID not specified',
        'E01010008' => 'Shop ID contains invalid characters or is too long',
        'E01010010' => 'Shop ID is invalid',
        'E01020001' => 'Shop Password not specified',
        'E01020008' => 'Shop Password contains invalid characters or is too long',
        'E01030002' => 'Shop ID and Password are invalid',
        'E01040001' => 'Order ID not specified',
        'E01040003' => 'Order ID too long',
        'E01040010' => 'Order ID previously used',
        'E01040013' => 'Order ID contains characters other than a-z, A-Z, 0-9 and -',
        'E01050001' => 'Process Classification not specified',
        'E01050002' => 'Process Classification is invalid',
        'E01050004' => 'Process Classification can not be executed',
        'E01060001' => 'Amount not specified',
        'E01060005' => 'Amount exceeds maximum allowed',
        'E01060006' => 'Amount contains non-numeric characters',
        'E01060010' => 'Capture Amount does not match Authorization Amount',
        'E01070005' => 'Tax/Shipping exceeds maximum allowed',
        'E01070006' => 'Tax/Shipping contains non-numeric characters',
        'E01080007' => 'User Authentication Flag is not 1 or 0',
        'E01080010' => 'User Authentication Flag does not match administration screen',
        'E01080101' => 'User Authentication Flag is 0, however store requires User Authentication',
        'E01090001' => 'Access ID not specified',
        'E01090008' => 'Access ID incorrectly formatted',
        'E01100001' => 'Access Password not specified',
        'E01100008' => 'Access Password incorrectly formatted',
        'E01110002' => 'Access ID and Password are invalid',
        'E01110010' => 'Transaction settlement is not complete',
        'E01130012' => 'Card Company Abbreviation is too long',
        'E01170001' => 'Card Number not specified',
        'E01170003' => 'Card Number too long',
        'E01170006' => 'Card Number contains non-numeric characters',
        'E01170011' => 'Card Number not 10-16 characters in length',
        'E01180001' => 'Expiration Date not specified',
        'E01180003' => 'Expiration Date is not four characters in length',
        'E01180006' => 'Expiration Date contains non-numeric characters',
        'E01190001' => 'Site ID is not specified',
        'E01190008' => 'Site ID incorrectly formatted',
        'E01200001' => 'Site Password not specified',
        'E01200008' => 'Site Password incorrectly formatted',
        'E01210002' => 'Site ID and Password are invalid',
        'E01220001' => 'Member ID is not specified',
        'E01220008' => 'Member ID incorrectly formatted',
        'E01230006' => 'Card Registration Consecutive Number contains non-numeric characters',
        'E01230009' => 'Card Registration Consecutive Number exceeds maximum registration capacity',
        'E01240002' => 'Card specified does not exist',
        'E01240012' => 'Member ID specified is redundant in file',
        'E01250008' => 'Card Password incorrectly formatted',
        'E01250010' => 'Card Password is invalid',
        'E01260001' => 'Payment Method not specified',
        'E01260002' => 'Payment Method is invalid',
        'E01260010' => 'Payment Method specified can not be used',
        'E01270001' => 'Number of Payments not specified',
        'E01270005' => 'Number of Payments exceeds maximum allowed',
        'E01270006' => 'Number of Payments contains non-numeric characters',
        'E01270010' => 'Number of Payments specified is invalid',
        'E01290001' => 'HTTP_ACCEPT not specified',
        'E01300001' => 'HTTP_USER_AGENT not specified',
        'E01310002' => 'Terminal not specified',
        'E01310007' => 'Terminal values other than 1 or 0 are for the terminal to use',
        'E01320012' => 'Client Field 1 too long',
        'E01330012' => 'Client Field 2 too long',
        'E01340012' => 'Client Field 3 too long',
        'E01350001' => 'MD not specified',
        'E01350008' => 'MD incorrectly formatted',
        'E01360001' => 'PaRes not specified',
        'E01370008' => 'User Authentication Display Name incorrectly formatted',
        'E01370012' => 'User Authentication Display Name too long',
        'E01390002' => 'Site ID and Member ID do not exist',
        'E01390010' => 'Site ID and Member ID already exist',
        'E01400007' => 'Client Field Flag is not 1 or 0',
        'E01410010' => 'Transaction is set to prohibited status',
        'E01420010' => 'Transaction authorization is too old',
        'E01430012' => 'Member Name too long',
        'E01440008' => 'Default Card Flag incorrectly formatted',
        'E01450008' => 'Product Code incorrectly formatted',
        'E01460008' => 'Security Code incorrectly formatted',
        'E01470008' => 'Card Registration Consecutive Number incorrectly formatted',
        'E01480008' => 'Cardholder Name incorrectly formatted',
        'E01490005' => 'Amount + Tax/Shipping exceeds maximum allowed',
        'E01800001' => 'PIN not specified',
        'E01800008' => 'PIN incorrectly formatted',
        'E01800010' => 'PIN is invalid',
        'E11010001' => 'Transaction settlement already complete',
        'E11010002' => 'Transaction settlement is not complete and thus can not be modified',
        'E11010003' => 'Transaction Process Classification can not be performed',
        'E11010010' => 'Transaction process can not be performed because transaction is more than 180 days old',
        'E11010011' => 'Transaction process can not be performed because transaction is more than 180 days old',
        'E11010012' => 'Transaction process can not be performed because transaction is more than 180 days old',
        'E11010013' => 'Transaction process can not be performed because transaction is more than 180 days old',
        'E11010014' => 'Transaction process can not be performed because transaction is more than 180 days old',
        'E11010099' => 'Card can not be used',
        'E11010999' => 'Card can not be used',
        'E21010001' => 'User Authentication failed - please try again',
        'E21010007' => 'User Authentication failed - please try again',
        'E21010999' => 'User Authentication failed - please try again',
        'E21020001' => 'User Authentication failed - please try again',
        'E21020002' => 'User Authentication failed - please try again',
        'E21020007' => 'User Authentication failed - please try again',
        'E21020999' => 'User Authentication failed - please try again',
        'E21010201' => 'Card does not support User Authentication',
        'E21010202' => 'Card does not support User Authentication',
        'E31500014' => 'Request method must be POST, not GET',
        'E41170002' => 'Card can not be used',
        'E41170099' => 'Card Number is incorrect',
        'E61010001' => 'Settlement process failed - please try again',
        'E61010002' => 'Settlement process failed - please try again',
        'E61010003' => 'Settlement process failed - please try again',
        'E61020001' => 'Settlement method has been disabled',
        'E82010001' => 'Error executing transaction',
        'E90010001' => 'Duplicate transaction',
        'E91019999' => 'Settlement process failed - please try again',
        'E91020001' => 'System communication timeout - please try again',
        'E91029999' => 'Settlement process failed - please try again',
        'E91050001' => 'Settlement process failed',
        'E91099999' => 'Settlement process failed - please try again',
        'E92000001' => 'System unable to process transaction - please try again',
        'M01001005' => 'Version Number too long',
        'M01002001' => 'Shop ID not specified',
        'M01002002' => 'Shop ID and Password are invalid',
        'M01002008' => 'Shop ID incorrectly formatted',
        'M01003001' => 'Shop Password not specified',
        'M01003008' => 'Shop Password incorrectly formatted',
        'M01004001' => 'Order ID not specified',
        'M01004002' => 'Order ID not part of a registered transaction',
        'M01004010' => 'Order ID previously used',
        'M01004012' => 'Order ID too long',
        'M01004013' => 'Order ID contains characters other than a-z, A-Z, 0-9 and -',
        'M01004014' => 'Order ID is already part of a transaction requesting settlement',
        'M01005001' => 'Amount not specified',
        'M01005005' => 'Amount too long',
        'M01005006' => 'Amount contains non-numeric characters',
        'M01005011' => 'Amount is outside valid range',
        'M01006005' => 'Tax/Shipping exceeds maximum allowed',
        'M01006006' => 'Tax/Shipping contains non-numeric characters',
        'M01007001' => 'Access ID not specified',
        'M01007008' => 'Access ID incorrectly formatted',
        'M01008001' => 'Access Password not specified',
        'M01008008' => 'Access Password incorrectly formatted',
        'M01009001' => 'Payment Destination Convenience Store Code not specified',
        'M01009002' => 'Payment Destination Convenience Store Code is incorrect',
        'M01009005' => 'Payment Destination Convenience Store Code too long',
        'M01010001' => 'Name not specified',
        'M01010012' => 'Name too long',
        'M01010013' => 'Name contains invalid characters',
        'M01011001' => 'Furigana not specified',
        'M01011012' => 'Furigana too long',
        'M01011013' => 'Furigana contains invalid characters',
        'M01012001' => 'Telephone Number not specified',
        'M01012005' => 'Telephone Number too long',
        'M01012008' => 'Telephone Number incorrectly formatted',
        'M01013005' => 'Number of Due Dates too long',
        'M01013006' => 'Number of Due Dates contains non-numeric characters',
        'M01013011' => 'Number of Due Dates is outside valid range',
        'M01014001' => 'Result Notice Destination Email not specified',
        'M01014005' => 'Result Notice Destination Email too long',
        'M01014008' => 'Result Notice Destination Email incorrectly formatted',
        'M01015005' => 'Merchant Email too long',
        'M01015008' => 'Merchant Email incorrectly formatted',
        'M01016012' => 'Reservation Number too long',
        'M01016013' => 'Reservation Number contains invalid characters',
        'M01017012' => 'Member Number too long',
        'M01017013' => 'Member Number contains invalid characters',
        'M01018012' => 'POS Register Display Column 1 too long',
        'M01018013' => 'POS Register Display Column 1 contains invalid characters',
        'M01019012' => 'POS Register Display Column 2 too long',
        'M01019013' => 'POS Register Display Column 2 contains invalid characters',
        'M01020012' => 'POS Register Display Column 3 too long',
        'M01020013' => 'POS Register Display Column 3 contains invalid characters',
        'M01021012' => 'POS Register Display Column 4 too long',
        'M01021013' => 'POS Register Display Column 4 contains invalid characters',
        'M01022012' => 'POS Register Display Column 5 too long',
        'M01022013' => 'POS Register Display Column 5 contains invalid characters',
        'M01023012' => 'POS Register Display Column 6 too long',
        'M01023013' => 'POS Register Display Column 6 contains invalid characters',
        'M01024012' => 'POS Register Display Column 7 too long',
        'M01024013' => 'POS Register Display Column 7 contains invalid characters',
        'M01025012' => 'POS Register Display Column 8 too long',
        'M01025013' => 'POS Register Display Column 8 contains invalid characters',
        'M01026012' => 'Receipt Display Column 1 too long',
        'M01026013' => 'Receipt Display Column 1 contains invalid characters',
        'M01027012' => 'Receipt Display Column 2 too long',
        'M01027013' => 'Receipt Display Column 2 contains invalid characters',
        'M01028012' => 'Receipt Display Column 3 too long',
        'M01028013' => 'Receipt Display Column 3 contains invalid characters',
        'M01029012' => 'Receipt Display Column 4 too long',
        'M01029013' => 'Receipt Display Column 4 contains invalid characters',
        'M01030012' => 'Receipt Display Column 5 too long',
        'M01030013' => 'Receipt Display Column 5 contains invalid characters',
        'M01031012' => 'Receipt Display Column 6 too long',
        'M01031013' => 'Receipt Display Column 6 contains invalid characters',
        'M01032012' => 'Receipt Display Column 7 too long',
        'M01032013' => 'Receipt Display Column 7 contains invalid characters',
        'M01033012' => 'Receipt Display Column 8 too long',
        'M01033013' => 'Receipt Display Column 8 contains invalid characters',
        'M01034012' => 'Receipt Display Column 9 too long',
        'M01034013' => 'Receipt Display Column 9 contains invalid characters',
        'M01035012' => 'Receipt Display Column 10 too long',
        'M01035013' => 'Receipt Display Column 10 contains invalid characters',
        'M01036001' => 'Contact Address not specified',
        'M01036012' => 'Contact Address too long',
        'M01036013' => 'Contact Address contains invalid characters',
        'M01037001' => 'Contact Telephone not specified',
        'M01037005' => 'Contact Telephone too long',
        'M01037008' => 'Contact Telephone contains characters other than 0-9 and -',
        'M01038001' => 'Contact Business Hours not specified',
        'M01038005' => 'Contact Business Hours too long',
        'M01038008' => 'Contact Business Hours contains characters other than 0-9, : and -',
        'M01039012' => 'Client Field 1 too long',
        'M01039013' => 'Client Field 1 contains invalid characters',
        'M01040012' => 'Client Field 2 too long',
        'M01040013' => 'Client Field 2 contains invalid characters',
        'M01041012' => 'Client Field 3 too long',
        'M01041013' => 'Client Field 3 contains invalid characters',
        'M01042005' => 'Result Return Method Flag too long',
        'M01042011' => 'Result Return Method Flag is not 1 or 0',
        'M01043001' => 'Product/Service Name not specified',
        'M01043012' => 'Product/Service Name too long',
        'M01043013' => 'Product/Service Name contains invalid characters',
        'M01044012' => 'Settlement Start Email Additional Information too long',
        'M01044013' => 'Settlement Start Email Additional Information contains invalid characters',
        'M01045012' => 'Settlement Completion Email Additional Information too long',
        'M01045013' => 'Settlement Completion Email Additional Information contains invalid characters',
        'M01046012' => 'Settlement Contents Confirmation Screen Additional Information too long',
        'M01046013' => 'Settlement Contents Confirmation Screen Additional Information contains invalid characters',
        'M01047012' => 'Settlement Contents Confirmation Screen Additional Information too long',
        'M01047013' => 'Settlement Contents Confirmation Screen Additional Information contains invalid characters',
        'M01048005' => 'Due Date for Payment (Seconds) too long',
        'M01048006' => 'Due Date for Payment (Seconds) contains non-numeric characters',
        'M01048011' => 'Due Date for Payment (Seconds) is outside valid range',
        'M01049012' => 'Settlement Start Email Additional Information too long',
        'M01049013' => 'Settlement Start Email Additional Information contains invalid characters',
        'M01050012' => 'Settlement Completion Email Additional Information too long',
        'M01050013' => 'Settlement Completion Email Additional Information contains invalid characters',
        'M01051001' => 'Settlement Method not specified',
        'M01051005' => 'Settlement Method too long',
        'M01051011' => 'Settlement Method is outside valid range',
        'M01053002' => 'Convenience Store specified can not be used',
        'M01054001' => 'Process Classification not specified',
        'M01054004' => 'Process Classification is invalid for current transaction status',
        'M01054010' => 'Process Classification specified is not defined',
        'M01055010' => 'Amount + Tax/Shipping does not match Transaction Amount + Tax/Shipping',
        'M01056001' => 'Redirect URL not specified',
        'M01056012' => 'Redurect URL too long',
        'M01057010' => 'Transaction is too old for cancellation',
        'M01058002' => 'Transaction specified does not exist',
        'M01058010' => 'Transaction Shop ID does not match specified Shop ID',
        'M01059005' => 'Return Destination URL too long',
        'M01060010' => 'Transaction authorization is too old',
        'M11010099' => 'Transaction settlement is not complete',
        'M11010999' => 'Transaction settlement may already be complete',
        'M91099999' => 'Settlement process failed',
        '42G020000' => 'Card balance is insufficient',
        '42G030000' => 'Card limit has been exceeded',
        '42G040000' => 'Card balance is insufficient',
        '42G050000' => 'Card limit has been exceeded',
        '42G120000' => 'Card is not valid for transactions',
        '42G220000' => 'Card is not valid for transactions',
        '42G300000' => 'Card is not valid for transactions',
        '42G420000' => 'PIN is incorrect',
        '42G440000' => 'Security code is incorrect',
        '42G530000' => 'Security code not provided',
        '42G540000' => 'Card is not valid for transactions',
        '42G550000' => 'Card limit has been exceeded',
        '42G560000' => 'Card is not valid for transactions',
        '42G600000' => 'Card is not valid for transactions',
        '42G610000' => 'Card is not valid for transactions',
        '42G650000' => 'Card number is incorrect',
        '42G670000' => 'Product code is incorrect',
        '42G680000' => 'Amount is incorrect',
        '42G690000' => 'Tax/Shipping is incorrect',
        '42G700000' => 'Number of bonuses is incorrect',
        '42G710000' => 'Bonus month is incorrect',
        '42G720000' => 'Bonus amount is incorrect',
        '42G730000' => 'Payment start month is incorrect',
        '42G740000' => 'Number of installments is incorrect',
        '42G750000' => 'Installment amount is incorrect',
        '42G760000' => 'Initial amount is incorrect',
        '42G770000' => 'Task classification is incorrect',
        '42G780000' => 'Payment classification is incorrect',
        '42G790000' => 'Reference classification is incorrect',
        '42G800000' => 'Cancellation classification is incorrect',
        '42G810000' => 'Cancellation handling classification is incorrect',
        '42G830000' => 'Expiration date is incorrect',
        '42G950000' => 'Card is not valid for transactions',
        '42G960000' => 'Card is not valid for transactions',
        '42G970000' => 'Card is not valid for transactions',
        '42G980000' => 'Card is not valid for transactions',
        '42G990000' => 'Card is not valid for transactions'
      }


      # @param [String] login     The GMO-PG ShopID (REQUIRED)
      # @param [String] password  The GMO-PG ShopPass (REQUIRED)
      # @param [Boolean] test     If the test server should be used instead of production
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Authorizes an amount on a user's card
      #
      # @param [Integer]    money       The number of yen
      # @param [CreditCard] creditcard  The user's credit card details
      # @param [Hash]       options     Please note that addresses are not sent to the API since it does not have fields for such
      # @return [MultiResponse]  Information about the authorization
      def authorize(money, creditcard, options = {})
        parameters = {}
        add_creditcard(parameters, creditcard)
        add_currency_code(parameters, money, options)
        add_invoice(parameters, options)
        add_customer_data(parameters, options)

        commit('AUTH', money, parameters)
      end

      # Captures the money from a previous authorization
      #
      # @param [Integer] money          The number of yen
      # @param [String]  authorization  The authorization attribute of the Response object from the authorize() request (AccessID-AccessPass)
      # @param [Hash]    options        Please note that addresses are not sent to the API since it does not have fields for such
      # @return [Response]  Information about the capture
      def capture(money, authorization, options = {})
        parameters = extract_authorization(authorization, {})

        commit('SALES', money, parameters)
      end

      # Peforms an instant purchase
      #
      # @param [Integer]    money       The number of yen
      # @param [CreditCard] creditcard  The user's credit card details
      # @param [Hash]       options     Please note that addresses are not sent to the API since it does not have fields for such
      # @return [MultiResponse]  Information about the purchase
      def purchase(money, creditcard, options = {})
        parameters = {}
        add_creditcard(parameters, creditcard)
        add_currency_code(parameters, money, options)
        add_invoice(parameters, options)
        add_customer_data(parameters, options)

        commit('CAPTURE', money, parameters)
      end

      # Cancels a transaction
      #
      # @param [String]  authorization  The authorization attribute of the Response object (AccessID-AccessPass)
      # @param [Hash]    options        Not used for this gateway
      # @return [Response]  Information about the void - authorization will be the same as what was passed as the authorization
      def void(authorization, options = {})
        parameters = extract_authorization(authorization, {})

        commit('VOID', nil, parameters)
      end

      # Refunds a part or the whole amount of a transaction
      #
      # @param [Integer] money           The number of yen
      # @param [String]  identification  The authorization attribute of the Response object (AccessID-AccessPass)
      # @param [Hash]    options         Not used for this gateway
      # @return [Response]  Information about the refund - authorization will be the same as what was passed as the identification
      def refund(money, identification, options = {})
        parameters = extract_authorization(identification, {})

        commit('REFUND', money, parameters)
      end

      # Order IDs can only ever be registered once per account. This method
      # allows looking up information about a transaction, such as the
      # authorization, via the Order ID.
      #
      # @param [String] order_id  The Order ID to lookup
      # @return [Response]  Information about the transaction, including the authorization
      def search(order_id)
        commit('SEARCH', nil, {:OrderID => order_id})
      end

      # Determines if a response indicates the order is previously used
      #
      # @param [Response] response  The response to check
      # @return [Boolean]
      def duplicate_order?(response)
        response.params.has_key?(:ErrInfo) and response.params[:ErrInfo] == DUPLICATE_ORDER_CODE
      end

      private

      # For requests that need to alter an existing Transaction, they pass an
      # "authorization" which is a concatenation of the AccessID and AccessPass.
      # This splits them apart and adds them to the parameters.
      #
      # @param [String] authorization  AccessID-AccessPass
      # @param [Hash]   parameters     The request parameters to add the access data to
      # @return [Hash]  The modified parameters
      def extract_authorization(authorization, parameters)
        id, pass = authorization.split('-')
        parameters[:AccessID] = id
        parameters[:AccessPass] = pass
        parameters
      end

      # Since the API does not have explicit fields for name, email and customer
      # ID, we stuff them in the ClientField1 and ClientField3. We use
      # ClientField1 for name and email since name will always be present.
      # ClientField2 ends up being used for the description (via add_invoice()),
      # and ClientField3 is used for the customer ID.
      #
      # @param [Hash] parameters  The data to be sent to the API
      # @param [Hash] options     The options the user passed to the class
      def add_customer_data(parameters, options)
        if options.has_key? :email
          parameters[:ClientField1] += " <#{options[:email]}>"
          parameters[:ClientField1].lstrip!
        end

        if options.has_key? :customer
          parameters[:ClientField3] = options[:customer]
        end
      end

      # The API does not have fields to transmit addresses
      def add_address(parameters, creditcard, options)
      end

      # The API only allows yen (JPY) as the currency, so we fail with anything
      # else.
      #
      # @param [Hash]    parameters  The data to be sent to the API
      # @param [Integer] money       The number of yen
      # @param [Hash]    options     The options the user passed to the class
      def add_currency_code(parameters, money, options)
        parameters[:currency] = options[:currency] || currency(money)
        unless parameters[:currency] == 'JPY'
          raise ArgumentError.new("Parameter: currency may only be JPY")
        end
      end

      # Set the order ID and description
      #
      # @param [Hash] parameters  The data to be sent to the API
      # @param [Hash] options     The options the user passed to the class
      def add_invoice(parameters, options)
        parameters[:OrderID] = options[:order_id]
        parameters[:ClientField2] = options[:description] if options[:description]
      end

      # Set the credit card details for the request
      #
      # @param [Hash]        parameters  The data to be sent to the API
      # @param [CreditCard]  creditcard  The CreditCard object for the user
      def add_creditcard(parameters, creditcard)
        parameters[:CardNo]       = creditcard.number
        parameters[:Expire]       = expdate(creditcard)
        parameters[:SecurityCode] = creditcard.verification_value

        # The GMO API doesn't have name fields, so we add them to the client field
        parameters[:ClientField1] = "#{creditcard.first_name} #{creditcard.last_name} #{parameters[:ClientField1]}".strip
      end

      # The API expects the expiration date in YYMM format
      #
      # @param [CreditCard]  creditcard  The CreditCard object for the user
      # @return [String]  The formatted expiration date
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{year[-2..-1]}#{month}"
      end

      # Runs a transaction on the API, returning the result
      #
      # @param [String]  process     Which process needs to be run: "AUTH", "CAPTURE", "REFUND", "SEARCH", "VOID", "RETURN", "SALES"
      # @param [Integer] money       The number of yen
      # @param [Hash]    parameters  Request information, using symbol keys
      # @return [Response|MultiResponse]  The response from the transaction. "AUTH" and "CAPTURE" processes will return a MultiResponse.
      def commit(process, money, parameters)
        if ['AUTH', 'CAPTURE'].include?(process)
          authorization = nil
          first_response_data = nil
          first_response = nil
          response = MultiResponse.run do |r|
            r.process do
              data = ssl_post *create_transaction_data(process, money, parameters)
              first_response_data = parse_response(data)
              first_response = create_response(first_response_data)
            end

            if first_response.success?
              r.process do
                data = ssl_post *execute_transaction_data(first_response_data, parameters)
                second_response_data = parse_response(data)
                create_response(second_response_data, first_response_data)
              end
            end
          end

          return response
        end

        if process == 'REFUND'
          # REFUND isn't a real process, instead it triggers a call to the
          # change API endpoint using the CAPTURE process
          data = ssl_post *change_alter_transaction_data('ChangeTran', 'CAPTURE', money, parameters)
          response_data = parse_response(data)

        elsif process == 'SEARCH'
          data = ssl_post *search_transaction_data(parameters)
          response_data = parse_response(data)

        elsif ['VOID', 'RETURN', 'SALES'].include?(process)
          # Returns and voids affect the whole amount
          if process != 'SALES'
            money = nil
          end

          data = ssl_post *change_alter_transaction_data('AlterTran', process, money, parameters)
          response_data = parse_response(data)
        end

        create_response(response_data)
      end

      # Fetches the text of an error based on the ErrInfo code, or "Success"
      # if the request did not return an error.
      #
      # @param [Hash] response  The parsed response (symbol keys) from the API
      # @return [String]  The message
      def message_from(response)
        if not response.has_key?(:ErrInfo)
          return 'Success'
        end

        # The ErrInfo key can contain a | separated string of multiple error
        # codes. By default we start at the end and work our way backwards to
        # try and find the highest-level one we can.
        if response[:ErrInfo].index('|')
          error_codes = response[:ErrInfo].split('|')
        else
          error_codes = [response[:ErrInfo]]
        end

        error_codes.reverse.each do |code|
          if ERROR_CODES.has_key?(code)
            return ERROR_CODES[code]
          end
        end

        "Error #{error_codes[-1]}"
      end

      # Creates the URL and POST data for fetching transaction info. Corresponds
      # to the SearchTrade.idPass API endpoint.
      #
      # @param [Hash]  parameters  Data for the request, using symbol keys
      # @return [Array]  First element is [String] URL, second is [String] post data
      def search_transaction_data(parameters)
        url = make_url('SearchTrade')

        data = {}
        data[:Version]  = '105'
        data[:ShopID]   = @options[:login]
        data[:ShopPass] = @options[:password]
        data[:OrderID]  = parameters[:OrderID]

        [url, data.to_query]
      end

      # Creates the URL and POST data for registering a transaction. Corresponds
      # to the EntryTran.idPass API endpoint.
      #
      # @param [String]  process     "AUTH" or "CAPTURE"
      # @param [Integer] money       The number of yen
      # @param [Hash]    parameters  Data for the request, using symbol keys
      # @return [Array]  First element is [String] URL, second is [String] post data
      def create_transaction_data(process, money, parameters)
        url = make_url('EntryTran')

        data = {}
        data[:Version]  = '105'
        data[:ShopID]   = @options[:login]
        data[:ShopPass] = @options[:password]
        data[:OrderID]  = parameters[:OrderID]
        data[:JobCd]    = process
        data[:Amount]   = amount(money)
        data[:Tax]      = '0'

        [url, data.to_query]
      end

      # Creates the URL and POST data to execute a transaction that has been
      # registered via create_transaction_data(). Corresponds with the
      # ExecTran.isPass API endpoint.
      #
      # @param [Hash] create_response  The parsed response from create_transaction_data()
      # @param [Hash] parameters       Data for the request, using symbol keys
      # @return [Array]  First element is [String] URL, second is [String] post data
      def execute_transaction_data(create_response, parameters)
        url = make_url('ExecTran')

        data = {}
        data[:Version]      = '105'
        data[:AccessID]     = create_response[:AccessID]
        data[:AccessPass]   = create_response[:AccessPass]
        data[:OrderID]      = parameters[:OrderID]
        data[:Method]       = '1' # Single lump-sum payment
        data[:CardNo]       = parameters[:CardNo]
        data[:Expire]       = parameters[:Expire]
        data[:SecurityCode] = parameters[:SecurityCode]
        data[:ClientField1] = clean_client_field(parameters[:ClientField1])
        data[:ClientField2] = clean_client_field(parameters[:ClientField2])
        data[:ClientField3] = clean_client_field(parameters[:ClientField3])

        [url, data.to_query]
      end

      # Creates the URL and POST data for modifying transactions. Corresponds
      # to the ChangeTran.idPass and AlterTran.idPass API endpoints.
      #
      # @param [String]  action      "ChangeTran" or "AlterTran"
      # @param [String]  process     "CAPTURE", "RETURN", "VOID" or "SALES"
      # @param [Integer] money       The number of yen
      # @param [Hash]    parameters  Data for the request, using symbol keys
      # @return [Array]  First element is [String] URL, second is [String] post data
      def change_alter_transaction_data(action, process, money, parameters)
        url = make_url(action)

        data = {}
        data[:Version]      = '105'
        data[:ShopID]       = @options[:login]
        data[:ShopPass]     = @options[:password]
        data[:AccessID]     = parameters[:AccessID]
        data[:AccessPass]   = parameters[:AccessPass]
        data[:JobCd]        = process
        if money
          data[:Amount] = amount(money)
          data[:Tax]    = '0'
        end

        [url, data.to_query]
      end

      # Ensures the CheckString field from the return value matches the values.
      # This should not be strictly necessary since the response is sent
      # directly back from a request make, but I added it for completeness.
      #
      # @param [String] data   The url-encoded response data from the API
      # @return [Boolean]  If the CheckString matched the data returned
      def verify_check_string(data)
        # The documentation about how to calculate the hash was woefully
        # under-documented, however through some guessing I was able to
        # determine that it creates an MD5 from the values of the fields
        # starting with OrderID and ending with TranData, concatenated with
        # the Shop Password.
        fields = [
          'OrderID',
          'Forward',
          'Method',
          'PayTimes',
          'Approve',
          'TranID',
          'TranDate'
        ]
        values_string = ''
        check_string = nil

        CGI.parse(data).each do |key, value|
          if value.length == 1
            value = value[0]
          end
          if fields.include?(key)
            values_string += value
          end
          if key == 'CheckString'
            check_string = value
          end
        end
        values_string += @options[:password]
        our_hash = Digest::MD5.hexdigest(values_string)
        check_string == our_hash
      end

      def make_url(action)
        url = test? ? self.test_url : self.live_url
        url += action + '.idPass'
      end

      # Parses the raw response data into a Hash
      #
      # @param [String] data  The url-encoded response from the API
      # @return [Hash]  The parsed data, using symbols for keys
      def parse_response(data)
        response = {}
        CGI.parse(data).each do |key, value|
          if value.length == 1
            value = value[0]
          end
          response[key.to_sym] = value
        end
        response
      end

      # Creates a Reponse object
      #
      # @param [Hash] response        The response data from the API
      # @param [Hash] first_response  The response data from the first API request
      # @return [Response]
      def create_response(response, first_response=nil)
        message = message_from(response)

        # This allows the second response to grab the auth info from the first
        first_response ||= response

        Response.new(!response.has_key?(:ErrCode), message, response,
          :test => test?,
          # The AccessPass and AccessID are used for all alterations to a
          # transaction, so we store that as the authorization instead of TranID
          :authorization => "#{first_response[:AccessID]}-#{first_response[:AccessPass]}"
        )
      end

      # The ClientField fields do not accept certain characters, so we strip
      # them out or convert them rather than having the transaction fail. Also,
      # they can not exceed 100 characters in length.
      #
      # @param [String] data  Data to clean
      # @return [String]  Cleaned, truncated data
      def clean_client_field(data)
        data = data.to_s
        data.gsub!(/[\^`|~\"']/, '')
        data.gsub!(/[{<]/, '(')
        data.gsub!(/[}>]/, ')')
        data.gsub!(/&/, 'and')
        data[0...100]
      end
    end
  end
end
