require 'securerandom'
require 'digest'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # ==== USA ePay Advanced SOAP Interface
    #
    # This class encapuslates USA ePay's Advanced SOAP Interface. The Advanced Soap Interface allows
    # standard transactions, storing customer information, and recurring billing. Storing sensitive
    # information on USA ePay's servers can help with PCI DSS compliance, since customer and card data
    # do not need to be stored locally.
    #
    # Make sure you have enabled this functionality for your account with USA ePay.
    #
    # Information about the Advanced SOAP interface is available on the {USA ePay wiki}[http://wiki.usaepay.com/developer/soap].
    #
    # ==== Login, Password, and Software ID
    #
    # Please follow all of USA ePay's directions for acquiring all accounts and settings.
    #
    # The value used for <tt>:login</tt> is the Key value found in the Merchant Console under Settings > Source
    # Key. You will have to add this key in the USA ePay Merchant Console.
    #
    # The value used for <tt>:password</tt> is the pin value also found and assigned in the Merchant Console under
    # Settings > Source Key. The pin is required to use all but basic transactions in the SOAP interface.
    # You will have to add the pin to your source key, as it defaults to none.
    #
    # The value used for the <tt>:software_id</tt> is found in the Developer's Login under the Developers Center
    # in your WSDL. It is the 8 character value in <soap:address> tag. A masked example:
    # <soap:address location="https://www.usaepay.com/soap/gate/XXXXXXXX"/>
    # It is also found in the link to your WSDL. This is required as every account has a different path
    # SOAP requests are submitted to. Optionally, you can provide the entire urls via <tt>:live_url</tt> and <tt>:test_url</tt>, if your prefer.
    #
    # ==== Responses
    # * <tt>#success?</tt> -- +true+ if transmitted and returned correctly
    # * <tt>#message</tt> --  response or fault message
    # * <tt>#authorization</tt> --  reference_number or nil
    # * <tt>#params</tt> --  hash of entire soap response contents
    #
    # ==== Address Options
    # * <tt>:billing_address/:shipping_address</tt> -- contains some extra options
    #   * <tt>:name</tt> -- virtual attribute; will split to first and last name
    #   * <tt>:first_name</tt>
    #   * <tt>:last_name</tt>
    #   * <tt>:address1 </tt>
    #   * <tt>:address2 </tt>
    #   * <tt>:city </tt>
    #   * <tt>:state </tt>
    #   * <tt>:zip </tt>
    #   * <tt>:country </tt>
    #   * <tt>:phone</tt>
    #   * <tt>:email</tt>
    #   * <tt>:fax</tt>
    #   * <tt>:company</tt>
    #
    # ==== Support:
    # * Questions: post to {active_merchant google group}[http://groups.google.com/group/activemerchant]
    # * Feedback/fixes: matt (at) nearapogee (dot) com
    #
    # ==== Links:
    # * {USA ePay Merchant Console}[https://sandbox.usaepay.com/login]
    # * {USA ePay Developer Login}[https://www.usaepay.com/developer/login]
    #
    class UsaEpayAdvancedGateway < Gateway
      API_VERSION = "1.4"

      TEST_URL_BASE = 'https://sandbox.usaepay.com/soap/gate/' #:nodoc:
      LIVE_URL_BASE = 'https://www.usaepay.com/soap/gate/' #:nodoc:

      self.test_url = TEST_URL_BASE
      self.live_url = LIVE_URL_BASE

      FAILURE_MESSAGE = "Default Failure" #:nodoc:

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'http://www.usaepay.com/'
      self.display_name = 'USA ePay Advanced SOAP Interface'

      CUSTOMER_OPTIONS = {
        :id => [:string, 'CustomerID'], # merchant assigned number
        :notes => [:string, 'Notes'],
        :data => [:string, 'CustomData'],
        :url => [:string, 'URL'],
        # Recurring Billing
        :enabled => [:boolean, 'Enabled'],
        :schedule => [:string, 'Schedule'],
        :number_left => [:integer, 'NumLeft'],
        :currency => [:string, 'Currency'],
        :description => [:string, 'Description'],
        :order_id => [:string, 'OrderID'],
        :user => [:string, 'User'],
        :source => [:string, 'Source'],
        :send_receipt => [:boolean, 'SendReceipt'],
        :receipt_note => [:string, 'ReceiptNote'],
        # Point of Sale
        :price_tier => [:string, 'PriceTier'],
        :tax_class => [:string, 'TaxClass'],
        :lookup_code => [:string, 'LookupCode']
      } #:nodoc:

      ADDRESS_OPTIONS = {
        :first_name => [:string, 'FirstName'],
        :last_name => [:string, 'LastName'],
        :address1 => [:string, 'Street'],
        :address2 => [:string, 'Street2'],
        :city => [:string, 'City'],
        :state => [:string, 'State'],
        :zip => [:string, 'Zip'],
        :country => [:string, 'Country'],
        :phone => [:string, 'Phone'],
        :email => [:string, 'Email'],
        :fax => [:string, 'Fax'],
        :company => [:string, 'Company']
      } #:nodoc:

      CUSTOMER_TRANSACTION_REQUEST_OPTIONS = {
        :command => [:string, 'Command'],
        :ignore_duplicate => [:boolean, 'IgnoreDuplicate'],
        :client_ip => [:string, 'ClientIP'],
        :customer_receipt => [:boolean, 'CustReceipt'],
        :customer_email => [:boolean, 'CustReceiptEmail'],
        :customer_template => [:boolean, 'CustReceiptName'],
        :merchant_receipt => [:boolean, 'MerchReceipt'],
        :merchant_email => [:boolean, 'MerchReceiptEmail'],
        :merchant_template => [:boolean, 'MerchReceiptName'],
        :recurring => [:boolean, 'isRecurring'],
        :verification_value => [:string, 'CardCode'],
        :software => [:string, 'Software']
      } #:nodoc:

      TRANSACTION_REQUEST_OBJECT_OPTIONS = {
        :command => [:string, 'Command'],
        :ignore_duplicate => [:boolean, 'IgnoreDuplicate'],
        :authorization_code => [:string, 'AuthCode'],
        :reference_number => [:string, 'RefNum'],
        :account_holder => [:string, 'AccountHolder'],
        :client_ip => [:string, 'ClientIP'],
        :customer_id => [:string, 'CustomerID'],
        :customer_receipt => [:boolean, 'CustReceipt'],
        :customer_template => [:boolean, 'CustReceiptName'],
        :software => [:string, 'Software']
      } #:nodoc:

      TRANSACTION_DETAIL_OPTIONS = {
        :invoice  => [:string, 'Invoice'],
        :po_number => [:string, 'PONum'],
        :order_id => [:string, 'OrderID'],
        :clerk => [:string, 'Clerk'],
        :terminal  => [:string, 'Terminal'],
        :table => [:string, 'Table'],
        :description => [:string, 'Description'],
        :comments => [:string, 'Comments'],
        :allow_partial_auth => [:boolean, 'AllowPartialAuth'],
        :currency => [:string, 'Currency'],
        :non_tax => [:boolean, 'NonTax'],
      } #:nodoc:

      TRANSACTION_DETAIL_MONEY_OPTIONS = {
        :amount => [:double, 'Amount'],
        :tax => [:double, 'Tax'],
        :tip => [:double, 'Tip'],
        :non_tax => [:boolean, 'NonTax'],
        :shipping => [:double, 'Shipping'],
        :discount => [:double, 'Discount'],
        :subtotal => [:double, 'Subtotal']
      } #:nodoc:

      CREDIT_CARD_DATA_OPTIONS = {
        :magnetic_stripe => [:string, 'MagStripe'],
        :dukpt => [:string, 'DUKPT'],
        :signature => [:string, 'Signature'],
        :terminal_type => [:string, 'TermType'],
        :magnetic_support => [:string, 'MagSupport'],
        :xid => [:string, 'XID'],
        :cavv => [:string, 'CAVV'],
        :eci => [:integer, 'ECI'],
        :internal_card_authorization => [:boolean, 'InternalCardAuth'],
        :pares => [:string, 'Pares']
      } #:nodoc:

      CHECK_DATA_OPTIONS = {
        :drivers_license => [:string, 'DriversLicense'],
        :drivers_license_state => [:string, 'DriversLicenseState'],
        :record_type => [:string, 'RecordType'],
        :aux_on_us => [:string, 'AuxOnUS'],
        :epc_code => [:string, 'EpcCode'],
        :front_image => [:string, 'FrontImage'],
        :back_image => [:string, 'BackImage']
      } #:nodoc:

      RECURRING_BILLING_OPTIONS = {
        :schedule => [:string, 'Schedule'],
        :number_left => [:integer, 'NumLeft'],
        :enabled => [:boolean, 'Enabled']
      } #:nodoc:

      AVS_RESULTS = {
        'Y' => %w( YYY Y YYA YYD ),
        'Z' => %w( NYZ Z ),
        'A' => %w( YNA A YNY ),
        'N' => %w( NNN N NN ),
        'X' => %w( YYX X ),
        'W' => %w( NYW W ),
        'XXW' => %w( XXW ),
        'XXU' => %w( XXU ),
        'R' => %w( XXR R U E ),
        'S' => %w( XXS S ),
        'XXE' => %w( XXE ),
        'G' => %w( XXG G C I ),
        'B' => %w( YYG B M ),
        'D' => %w( GGG D ),
        'P' => %w( YGG P )
      }.inject({}) do |map, (type, codes)|
        codes.each { |code| map[code] = type }
        map
      end #:nodoc:

      AVS_CUSTOM_MESSAGES = {
        'XXW' => 'Card number not on file.',
        'XXU' => 'Address information not verified for domestic transaction.',
        'XXE' => 'Address verification not allowed for card type.'
      } #:nodoc:

      # Create a new gateway.
      #
      # ==== Required
      # * At least the live_url OR the software_id must be present.
      #   * <tt>:software_id</tt> -- 8 character software id
      #   OR
      #   * <tt>:test_url</tt> -- full url for testing
      #   * <tt>:live_url</tt> -- full url for live/production
      #
      # ==== Optional
      # * <tt>:soap_response</tt> -- set to +true+ to add :soap_response to the params hash containing the entire soap xml message
      #
      def initialize(options = {})
        requires!(options, :login, :password)

        if options[:software_id]
          self.live_url = "#{LIVE_URL_BASE}#{options[:software_id].to_s}"
          self.test_url = "#{TEST_URL_BASE}#{options[:software_id].to_s}"
        else
          self.live_url = options[:live_url].to_s
          self.test_url = options[:test_url].to_s if options[:test_url]
        end

        super
      end

      # Standard Gateway Methods ======================================

      # Make a purchase with a credit card. (Authorize and
      # capture for settlement.)
      #
      # Note: See run_transaction for additional options.
      #
      def purchase(money, creditcard, options={})
        run_sale(options.merge!(:amount => money, :payment_method => creditcard))
      end

      # Authorize an amount on a credit card or account.
      #
      # Note: See run_transaction for additional options.
      #
      def authorize(money, creditcard, options={})
        run_auth_only(options.merge!(:amount => money, :payment_method => creditcard))
      end

      # Capture an authorized transaction.
      #
      # Note: See run_transaction for additional options.
      #
      def capture(money, identification, options={})
        capture_transaction(options.merge!(:amount => money, :reference_number => identification))
      end

      # Void a previous transaction that has not been settled.
      #
      # Note: See run_transaction for additional options.
      #
      def void(identification, options={})
        void_transaction(options.merge!(:reference_number => identification))
      end

      # Refund a previous transaction.
      #
      # Note: See run_transaction for additional options.
      #
      def refund(money, identification, options={})
        refund_transaction(options.merge!(:amount => money, :reference_number => identification))
      end

      def credit(money, identification, options={})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      # Customer ======================================================

      # Add a customer.
      #
      # ==== Options
      # * <tt>:id</tt> -- merchant assigned id
      # * <tt>:notes</tt> -- notes about customer
      # * <tt>:data</tt> -- base64 data about customer
      # * <tt>:url</tt> -- customer website
      # * <tt>:billing_address</tt> -- usual options
      # * <tt>:payment_methods</tt> -- array of payment method hashes.
      #   * <tt>:method</tt> -- credit_card or check
      #   * <tt>:name</tt> -- optional name/label for the method
      #   * <tt>:sort</tt> -- optional integer value specifying the backup sort order, 0 is default
      #
      # ==== Recurring Options
      # * <tt>:enabled</tt> -- +true+ enables recurring
      # * <tt>:schedule</tt> -- daily, weekly, bi-weekly (every two weeks), monthly, bi-monthly (every two months), quarterly, bi-annually (every six months), annually, first of month, last day of month
      # * <tt>:number_left</tt> -- number of payments left; -1 for unlimited
      # * <tt>:next</tt> -- date of next payment (Date/Time)
      # * <tt>:amount</tt> -- amount of recurring payment
      # * <tt>:tax</tt> -- tax portion of amount
      # * <tt>:currency</tt> -- numeric currency code
      # * <tt>:description</tt> -- description of transaction
      # * <tt>:order_id</tt> -- transaction order id
      # * <tt>:user</tt> -- merchant username assigned to transaction
      # * <tt>:source</tt> -- name of source key assigned to billing
      # * <tt>:send_receipt</tt> -- +true+ to send client a receipt
      # * <tt>:receipt_note</tt> -- leave a note on the receipt
      #
      # ==== Point of Sale Options
      # * <tt>:price_tier</tt> -- name of customer price tier
      # * <tt>:tax_class</tt> -- tax class
      # * <tt>:lookup_code</tt> -- lookup code from customer/member id card; barcode or magnetic stripe; can be assigned by merchant; defaults to system assigned if blank
      #
      # ==== Response
      # * <tt>#message</tt> -- customer number assigned by gateway
      #
      def add_customer(options={})
        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Update a customer by replacing all of the customer details.
      #
      # ==== Required
      # * <tt>:customer_number</tt> -- customer to update
      #
      # ==== Options
      #  * Same as add_customer
      #
      def update_customer(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Enable a customer for recurring billing.
      #
      # Note: Customer does not need to have all recurring parameters to succeed.
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      #
      def enable_customer(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Disable a customer for recurring billing.
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      #
      def disable_customer(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Add a payment method to a customer.
      #
      # ==== Required
      # * <tt>:customer_number</tt> -- number returned by add_customer response.message
      # * <tt>:payment_method</tt>
      #   * <tt>:method</tt> -- credit_card or check
      #   * <tt>:name</tt> -- optional name/label for the method
      #   * <tt>:sort</tt> -- an integer value specifying the backup sort order, 0 is default
      #
      # ==== Optional
      # * <tt>:make_default</tt> -- set +true+ to make default
      # * <tt>:verify</tt> -- set +true+ to run auth_only verification; throws fault if cannot verify
      #
      # ==== Response
      # * <tt>#message</tt> -- method_id of new customer payment method
      #
      def add_customer_payment_method(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Retrive all of the payment methods belonging to a customer
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- either a single hash or an array of hashes of payment methods
      #
      def get_customer_payment_methods(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Retrive one of the payment methods belonging to a customer
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      # * <tt>:method_id</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- hash of payment method
      #
      def get_customer_payment_method(options={})
        requires! options, :customer_number, :method_id

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Update a customer payment method.
      #
      # ==== Required
      # * <tt>:method_id</tt> -- method_id to update
      #
      # ==== Options
      # * <tt>:method</tt> -- credit_card or check
      # * <tt>:name</tt> -- optional name/label for the method
      # * <tt>:sort</tt> -- an integer value specifying the backup sort order, 0 is default
      # * <tt>:verify</tt> -- set +true+ to run auth_only verification; throws fault if cannot verify
      #
      # ==== Response
      # * <tt>#message</tt> -- hash of payment method
      #
      def update_customer_payment_method(options={})
        requires! options, :method_id

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Delete one the payment methods belonging to a customer
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      # * <tt>:method_id</tt>
      #
      def delete_customer_payment_method(options={})
        requires! options, :customer_number, :method_id

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Delete a customer.
      #
      # ==== Required
      # * <tt>:customer_number</tt>
      #
      def delete_customer(options={})
        requires! options, :customer_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Run a transaction for an existing customer in the database.
      #
      # ==== Required Options
      # * <tt>:customer_number</tt> -- gateway assigned identifier
      # * <tt>:command</tt> -- Sale, AuthOnly, Credit, Check, CheckCredit
      # * <tt>:amount</tt> -- total amount
      #
      # ==== Options
      # * <tt>:method_id</tt> -- which payment method to use, 0/nil/omitted for default method
      # * <tt>:ignore_duplicate</tt> -- +true+ overrides duplicate transaction
      # * <tt>:client_ip</tt> -- client ip address
      # * <tt>:customer_receipt</tt> -- +true+, sends receipt to customer. active_merchant defaults to +false+
      # * <tt>:customer_email</tt> -- specify if different than customer record
      # * <tt>:customer_template</tt> -- name of template
      # * <tt>:merchant_receipt</tt> -- +true+, sends receipt to merchant. active_merchant defaults to +false+
      # * <tt>:merchant_email</tt> -- required if :merchant_receipt set to +true+
      # * <tt>:merchant_template</tt> -- name of template
      # * <tt>:recurring</tt> -- defaults to +false+ *see documentation*
      # * <tt>:verification_value</tt> -- pci forbids storage of this value, only required for CVV2 validation
      # * <tt>:software</tt> -- active_merchant sets to required gateway option value
      # * <tt>:line_items</tt> -- XXX not implemented yet
      # * <tt>:custom_fields</tt> -- XXX not implemented yet
      #
      # ==== Transaction Options
      # * <tt>:invoice</tt> -- transaction invoice number; truncated to 10 characters; defaults to reference_number
      # * <tt>:po_number</tt> -- commercial purchase order number; upto 25 characters
      # * <tt>:order_id</tt> -- should be used to assign a unique id; upto 64 characters
      # * <tt>:clerk</tt> -- sales clerk
      # * <tt>:terminal</tt> -- terminal name
      # * <tt>:table</tt> -- table name/number
      # * <tt>:description</tt> -- description
      # * <tt>:comments</tt> -- comments
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      # * <tt>:currency</tt> -- numeric currency code
      # * <tt>:tax</tt> -- tax portion of amount
      # * <tt>:tip</tt> -- tip portion of amount
      # * <tt>:non_tax</tt> -- +true+ if transaction is non-taxable
      # * <tt>:shipping</tt> -- shipping portion of amount
      # * <tt>:discount</tt> -- amount of discount
      # * <tt>:subtotal</tt> -- amount of transaction before tax, tip, shipping, and discount are applied
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def run_customer_transaction(options={})
        requires! options, :customer_number, :command, :amount

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Transactions ==================================================

      # Run a transaction.
      #
      # Note: run_sale, run_auth_only, run_credit, run_check_sale, run_check_credit
      # methods are also available. Each takes the same options as
      # run_transaction, but the :command option is not required.
      #
      # Recurring Note: If recurring options are included USA ePay will create a
      # new customer record with the supplied information. The customer number
      # will be returned in the response.
      #
      # ==== Options
      # * <tt>:payment_method</tt> -- credit_card or check
      # * <tt>:command</tt> -- sale, credit, void, creditvoid, authonly, capture, postauth, check, checkcredit; defaults to sale; only required for run_transaction when other than sale
      # * <tt>:reference_number</tt> -- for the original transaction; obtained by sale or authonly
      # * <tt>:authorization_code</tt> -- required for postauth; obtained offline
      # * <tt>:ignore_duplicate</tt> -- set +true+ if you want to override the duplicate transaction handling
      # * <tt>:account_holder</tt> -- name of account holder
      # * <tt>:customer_id</tt> -- merchant assigned id
      # * <tt>:customer_receipt</tt> -- set +true+ to email receipt to billing email address
      # * <tt>:customer_template</tt> -- name of template
      # * <tt>:software</tt> -- stamp merchant software version for tracking
      # * <tt>:billing_address</tt> -- see UsaEpayCimGateway documentation for all address fields
      # * <tt>:shipping_address</tt> -- see UsaEpayCimGateway documentation for all address fields
      # * <tt>:recurring</tt> -- used for recurring billing transactions
      #   * <tt>:schedule</tt> -- disabled, daily, weekly, bi-weekly (every two weeks), monthly, bi-monthly (every two months), quarterly, bi-annually (every six months), annually
      #   * <tt>:next</tt> -- date customer billed next (Date/Time)
      #   * <tt>:expire</tt> -- date the recurring transactions end (Date/Time)
      #   * <tt>:number_left</tt> -- transactions remaining in billing cycle
      #   * <tt>:amount</tt> -- amount to be billed each recurring transaction
      #   * <tt>:enabled</tt> -- states if currently active
      # * <tt>:line_items</tt> -- XXX not implemented yet
      # * <tt>:custom_fields</tt> -- XXX not implemented yet
      #
      # ==== Transaction Options
      # * <tt>:amount</tt> -- total amount
      # * <tt>:invoice</tt> -- transaction invoice number; truncated to 10 characters; defaults to reference_number
      # * <tt>:po_number</tt> -- commercial purchase order number; upto 25 characters
      # * <tt>:order_id</tt> -- should be used to assign a unique id; upto 64 characters
      # * <tt>:clerk</tt> -- sales clerk
      # * <tt>:terminal</tt> -- terminal name
      # * <tt>:table</tt> -- table name/number
      # * <tt>:description</tt> -- description
      # * <tt>:comments</tt> -- comments
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      # * <tt>:currency</tt> -- numeric currency code
      # * <tt>:tax</tt> -- tax portion of amount
      # * <tt>:tip</tt> -- tip portion of amount
      # * <tt>:non_tax</tt> -- +true+ if transaction is non-taxable
      # * <tt>:shipping</tt> -- shipping portion of amount
      # * <tt>:discount</tt> -- amount of discount
      # * <tt>:subtotal</tt> -- amount of transaction before tax, tip, shipping, and discount are applied
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def run_transaction(options={})
        request = build_request(__method__, options)
        commit(__method__, request)
      end

      TRANSACTION_METHODS = [
        :run_sale, :run_auth_only, :run_credit,
        :run_check_sale, :run_check_credit
      ] #:nodoc:

      TRANSACTION_METHODS.each do |method|
        define_method method do |options|
          request = build_request(method, options)
          commit(method, request)
        end
      end

      # Post an authorization code obtained offline.
      #
      # ==== Required
      # * <tt>:authorization_code</tt> -- obtained offline
      #
      # ==== Options
      # * Same as run_transaction
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def post_auth(options={})
        requires! options, :authorization_code

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Capture an authorized transaction and move it into the current batch
      # for settlement.
      #
      # Note: Check with merchant bank for details/restrictions on differing
      # amounts than the original authorization.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Options
      # * <tt>:amount</tt> -- may be different than original amount; 0 will void authorization
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def capture_transaction(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Void a transaction.
      #
      # Note: Can only be voided before being settled.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def void_transaction(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Refund transaction.
      #
      # Note: Required after a transaction has been settled. Refunds
      # both credit card and check transactions.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      # * <tt>:amount</tt> -- amount to refund; 0 will refund original amount
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def refund_transaction(options={})
        requires! options, :reference_number, :amount

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Override transaction flagged for manager approval.
      #
      # Note: Checks only!
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Options
      # * <tt>:reason</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def override_transaction(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Quick Transactions ============================================

      # Run a sale transaction based off of a past transaction.
      #
      # Transfers referenced transaction's payment method to this
      # transaction. As of 6/2011, USA ePay blocks credit card numbers
      # at 3 years.
      #
      # ==== Required
      # * <tt>:reference_number</tt> -- transaction to reference payment from
      # * <tt>:amount</tt> -- total amount
      #
      # ==== Options
      # * <tt>:authorize_only</tt> -- set +true+ if you just want to authorize
      #
      # ==== Transaction Options
      # * <tt>:invoice</tt> -- transaction invoice number; truncated to 10 characters; defaults to reference_number
      # * <tt>:po_number</tt> -- commercial purchase order number; upto 25 characters
      # * <tt>:order_id</tt> -- should be used to assign a unique id; upto 64 characters
      # * <tt>:clerk</tt> -- sales clerk
      # * <tt>:terminal</tt> -- terminal name
      # * <tt>:table</tt> -- table name/number
      # * <tt>:description</tt> -- description
      # * <tt>:comments</tt> -- comments
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      # * <tt>:currency</tt> -- numeric currency code
      # * <tt>:tax</tt> -- tax portion of amount
      # * <tt>:tip</tt> -- tip portion of amount
      # * <tt>:non_tax</tt> -- +true+ if transaction is non-taxable
      # * <tt>:shipping</tt> -- shipping portion of amount
      # * <tt>:discount</tt> -- amount of discount
      # * <tt>:subtotal</tt> -- amount of transaction before tax, tip, shipping, and discount are applied
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def run_quick_sale(options={})
        requires! options, :reference_number, :amount

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Run a credit based off of a past transaction.
      #
      # Transfers referenced transaction's payment method to this
      # transaction. As of 6/2011, USA ePay blocks credit card numbers
      # at 3 years.
      #
      # ==== Required
      # * <tt>:reference_number</tt> -- transaction to reference payment from
      #
      # ==== Transaction Options
      # * <tt>:amount</tt> -- total amount
      # * <tt>:invoice</tt> -- transaction invoice number; truncated to 10 characters; defaults to reference_number
      # * <tt>:po_number</tt> -- commercial purchase order number; upto 25 characters
      # * <tt>:order_id</tt> -- should be used to assign a unique id; upto 64 characters
      # * <tt>:clerk</tt> -- sales clerk
      # * <tt>:terminal</tt> -- terminal name
      # * <tt>:table</tt> -- table name/number
      # * <tt>:description</tt> -- description
      # * <tt>:comments</tt> -- comments
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      # * <tt>:currency</tt> -- numeric currency code
      # * <tt>:tax</tt> -- tax portion of amount
      # * <tt>:tip</tt> -- tip portion of amount
      # * <tt>:non_tax</tt> -- +true+ if transaction is non-taxable
      # * <tt>:shipping</tt> -- shipping portion of amount
      # * <tt>:discount</tt> -- amount of discount
      # * <tt>:subtotal</tt> -- amount of transaction before tax, tip, shipping, and discount are applied
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction response hash
      #
      def run_quick_credit(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Transaction Status ============================================

      # Retrieve details of a specified transaction.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- transaction hash
      #
      def get_transaction(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Check status of a transaction.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Response
      # * <tt>response.success</tt> -- success of the referenced transaction
      # * <tt>response.message</tt> -- message of the referenced transaction
      # * <tt>response.authorization</tt> -- same as :reference_number in options
      #
      def get_transaction_status(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Check status of a transaction (custom).
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      # * <tt>:fields</tt> -- string array of fields to retrieve
      #   * <tt>Response.AuthCode</tt>
      #   * <tt>Response.AvsResult</tt>
      #   * <tt>Response.AvsResultCode</tt>
      #   * <tt>Response.BatchNum</tt>
      #   * <tt>Response.CardCodeResult</tt>
      #   * <tt>Response.CardCodeResultCode</tt>
      #   * <tt>Response.ConversionRate</tt>
      #   * <tt>Response.ConvertedAmount</tt>
      #   * <tt>Response.ConvertedAmountCurrency</tt>
      #   * <tt>Response.Error</tt>
      #   * <tt>Response.ErrorCode</tt>
      #   * <tt>Response.RefNum</tt>
      #   * <tt>Response.Result</tt>
      #   * <tt>Response.ResultCode</tt>
      #   * <tt>Response.Status</tt>
      #   * <tt>Response.StatusCode</tt>
      #   * <tt>CheckTrace.TrackingNum</tt>
      #   * <tt>CheckTrace.Effective</tt>
      #   * <tt>CheckTrace.Processed</tt>
      #   * <tt>CheckTrace.Settled</tt>
      #   * <tt>CheckTrace.Returned</tt>
      #   * <tt>CheckTrace.BankNote</tt>
      #   * <tt>DateTime</tt>
      #   * <tt>AccountHolder</tt>
      #   * <tt>Details.Invoice</tt>
      #   * <tt>Details.PoNum</tt>
      #   * <tt>Details.OrderID</tt>
      #   * <tt>Details.Clerk</tt>
      #   * <tt>Details.Terminal</tt>
      #   * <tt>Details.Table</tt>
      #   * <tt>Details.Description</tt>
      #   * <tt>Details.Amount</tt>
      #   * <tt>Details.Currency</tt>
      #   * <tt>Details.Tax</tt>
      #   * <tt>Details.Tip</tt>
      #   * <tt>Details.NonTax</tt>
      #   * <tt>Details.Shipping</tt>
      #   * <tt>Details.Discount</tt>
      #   * <tt>Details.Subtotal</tt>
      #   * <tt>CreditCardData.CardType</tt>
      #   * <tt>CreditCardData.CardNumber</tt>
      #   * <tt>CreditCardData.CardExpiration</tt>
      #   * <tt>CreditCardData.CardCode</tt>
      #   * <tt>CreditCardData.AvsStreet</tt>
      #   * <tt>CreditCardData.AvsZip</tt>
      #   * <tt>CreditCardData.CardPresent</tt>
      #   * <tt>CheckData.CheckNumber</tt>
      #   * <tt>CheckData.Routing</tt>
      #   * <tt>CheckData.Account</tt>
      #   * <tt>CheckData.SSN</tt>
      #   * <tt>CheckData.DriversLicense</tt>
      #   * <tt>CheckData.DriversLicenseState</tt>
      #   * <tt>CheckData.RecordType</tt>
      #   * <tt>User</tt>
      #   * <tt>Source</tt>
      #   * <tt>ServerIP</tt>
      #   * <tt>ClientIP</tt>
      #   * <tt>CustomerID</tt>
      #   * <tt>BillingAddress.FirstName</tt>
      #   * <tt>BillingAddress.LastName</tt>
      #   * <tt>BillingAddress.Company</tt>
      #   * <tt>BillingAddress.Street</tt>
      #   * <tt>BillingAddress.Street2</tt>
      #   * <tt>BillingAddress.City</tt>
      #   * <tt>BillingAddress.State</tt>
      #   * <tt>BillingAddress.Zip</tt>
      #   * <tt>BillingAddress.Country</tt>
      #   * <tt>BillingAddress.Phone</tt>
      #   * <tt>BillingAddress.Fax</tt>
      #   * <tt>BillingAddress.Email</tt>
      #   * <tt>ShippingAddress.FirstName</tt>
      #   * <tt>ShippingAddress.LastName</tt>
      #   * <tt>ShippingAddress.Company</tt>
      #   * <tt>ShippingAddress.Street</tt>
      #   * <tt>ShippingAddress.Street2</tt>
      #   * <tt>ShippingAddress.City</tt>
      #   * <tt>ShippingAddress.State</tt>
      #   * <tt>ShippingAddress.Zip</tt>
      #   * <tt>ShippingAddress.Country</tt>
      #   * <tt>ShippingAddress.Phone</tt>
      #   * <tt>ShippingAddress.Fax</tt>
      #   * <tt>ShippingAddress.Email</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- hash; keys are the field values
      #
      def get_transaction_custom(options={})
        requires! options, :reference_number, :fields

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Check status of a check transaction.
      #
      # ==== Required
      # * <tt>:reference_number</tt>
      #
      # ==== Response
      # * <tt>#message</tt> -- check trace hash
      #
      def get_check_trace(options={})
        requires! options, :reference_number

        request = build_request(__method__, options)
        commit(__method__, request)
      end

      # Account =======================================================

      # Retrieve merchant account details
      #
      # ==== Response
      # * <tt>#message</tt> -- account hash
      #
      def get_account_details
        request = build_request(__method__)
        commit(__method__, request)
      end

      # Builders ======================================================

      private

      # Build soap header, etc.
      def build_request(action, options = {})
        soap = Builder::XmlMarkup.new
        soap.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        soap.tag! "SOAP-ENV:Envelope",
          'xmlns:SOAP-ENV' => 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:ns1' => 'urn:usaepay',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:SOAP-ENC' => 'http://schemas.xmlsoap.org/soap/encoding/',
          'SOAP-ENV:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/' do
          soap.tag! "SOAP-ENV:Body" do
            send("build_#{action}", soap, options)
          end
        end
        soap.target!
      end

      # Build generic tag.
      def build_tag(soap, type, tag, value)
        soap.tag!(tag, value, 'xsi:type' => "xsd:#{type}") if value != nil
      end

      # Build token.
      def build_token(soap, options)
        seed = SecureRandom.base64(32)
        hash = Digest::SHA1.hexdigest("#{@options[:login]}#{seed}#{@options[:password].to_s.strip}")
        soap.Token 'xsi:type' => 'ns1:ueSecurityToken' do
          build_tag soap, :string, 'ClientIP', options[:client_ip]
          soap.PinHash 'xsi:type' => 'ns1:ueHash' do
            build_tag soap, :string, "HashValue", hash
            build_tag soap, :string, "Seed", seed
            build_tag soap, :string, "Type", 'sha1'
          end
          build_tag soap, :string, 'SourceKey', @options[:login]
        end
      end

      # Customer ======================================================

      def build_add_customer(soap, options)
        soap.tag! "ns1:addCustomer" do
          build_token soap, options
          build_customer_data soap, options
          build_tag soap, :double, 'Amount', amount(options[:amount])
          build_tag soap, :double, 'Tax', amount(options[:tax])
          build_tag soap, :string, 'Next', options[:next].strftime("%Y-%m-%d") if options[:next]
        end
      end

      def build_customer(soap, options, type, add_customer_data=false)
        soap.tag! "ns1:#{type}" do
          build_token soap, options
          build_tag soap, :integer, 'CustNum', options[:customer_number]
          build_customer_data soap, options if add_customer_data
        end
      end

      def build_update_customer(soap, options)
        build_customer(soap, options, 'updateCustomer', true)
      end

      def build_enable_customer(soap, options)
        build_customer(soap, options, 'enableCustomer')
      end

      def build_disable_customer(soap, options)
        build_customer(soap, options, 'disableCustomer')
      end

      def build_delete_customer(soap, options)
        build_customer(soap, options, 'deleteCustomer')
      end

      def build_add_customer_payment_method(soap, options)
        soap.tag! "ns1:addCustomerPaymentMethod" do
          build_token soap, options
          build_tag soap, :integer, 'CustNum', options[:customer_number]
          build_customer_payment_methods soap, options
          build_tag soap, :boolean, 'MakeDefault', options[:make_default]
          build_tag soap, :boolean, 'Verify', options[:verify]
        end
      end

      def build_get_customer_payment_method(soap, options)
        soap.tag! 'ns1:getCustomerPaymentMethod' do
          build_token soap, options
          build_tag soap, :integer, 'CustNum', options[:customer_number]
          build_tag soap, :integer, 'MethodID', options[:method_id]
        end
      end

      def build_get_customer_payment_methods(soap, options)
        build_customer(soap, options, 'getCustomerPaymentMethods')
      end

      def build_update_customer_payment_method(soap, options)
        soap.tag! 'ns1:updateCustomerPaymentMethod' do
          build_token soap, options
          build_customer_payment_methods soap, options
          build_tag soap, :boolean, 'Verify', options[:verify]
        end
      end

      def build_delete_customer_payment_method(soap, options)
        soap.tag! "ns1:deleteCustomerPaymentMethod" do
          build_token soap, options
          build_tag soap, :integer, 'Custnum', options[:customer_number]
          build_tag soap, :integer, 'PaymentMethodID', options[:method_id]
        end
      end

      def build_run_customer_transaction(soap, options)
        soap.tag! "ns1:runCustomerTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'CustNum', options[:customer_number]
          build_tag soap, :integer, 'PaymentMethodID', options[:method_id] || 0
          build_customer_transaction soap, options
        end
      end

      # Transactions ==================================================

      def build_run_transaction(soap, options)
        soap.tag! 'ns1:runTransaction' do
          build_token soap, options
          build_transaction_request_object soap, options, 'Parameters'
        end
      end

      def build_run_sale(soap, options)
        soap.tag! 'ns1:runSale' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_run_auth_only(soap, options)
        soap.tag! 'ns1:runAuthOnly' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_run_credit(soap, options)
        soap.tag! 'ns1:runCredit' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_run_check_sale(soap, options)
        soap.tag! 'ns1:runCheckSale' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_run_check_credit(soap, options)
        soap.tag! 'ns1:runCheckCredit' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_post_auth(soap, options)
        soap.tag! 'ns1:postAuth' do
          build_token soap, options
          build_transaction_request_object soap, options
        end
      end

      def build_run_quick_sale(soap, options)
        soap.tag! 'ns1:runQuickSale' do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_transaction_detail soap, options
          build_tag soap, :boolean, 'AuthOnly', options[:authorize_only] || false
        end
      end

      def build_run_quick_credit(soap, options)
        soap.tag! 'ns1:runQuickCredit' do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_transaction_detail soap, options
        end
      end

      def build_get_transaction(soap, options)
        soap.tag! "ns1:getTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
        end
      end

      def build_get_transaction_status(soap, options)
        soap.tag! "ns1:getTransactionStatus" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
        end
      end

      def build_get_transaction_custom(soap, options)
        soap.tag! "ns1:getTransactionCustom" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_transaction_field_array soap, options
        end
      end

      def build_get_check_trace(soap, options)
        soap.tag! "ns1:getCheckTrace" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
        end
      end

      def build_capture_transaction(soap, options)
        soap.tag! "ns1:captureTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_tag soap, :double, 'Amount', amount(options[:amount])
        end
      end

      def build_void_transaction(soap, options)
        soap.tag! "ns1:voidTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
        end
      end

      def build_refund_transaction(soap, options)
        soap.tag! "ns1:refundTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_tag soap, :integer, 'Amount', amount(options[:amount])
        end
      end

      def build_override_transaction(soap, options)
        soap.tag! "ns1:overrideTransaction" do
          build_token soap, options
          build_tag soap, :integer, 'RefNum', options[:reference_number]
          build_tag soap, :string, 'Reason', options[:reason]
        end
      end

      # Account =======================================================

      def build_get_account_details(soap, options)
        soap.tag! "ns1:getAccountDetails" do
          build_token soap, options
        end
      end

      # Customer Helpers ==============================================

      def build_customer_data(soap, options)
        soap.CustomerData 'xsi:type' => 'ns1:CustomerObject' do
          CUSTOMER_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
          build_billing_address soap, options
          build_customer_payments soap, options
          build_custom_fields soap, options
        end
      end

      def build_customer_payments(soap, options)
        if options[:payment_methods]
          length = options[:payment_methods].length
          soap.PaymentMethods 'SOAP-ENC:arrayType' => "ns1:PaymentMethod[#{length}]",
            'xsi:type' =>"ns1:PaymentMethodArray" do
            build_customer_payment_methods soap, options
          end
        end
      end

      def extract_methods_and_tag(options)
        case
        when options[:payment_method] && !options[:payment_methods]
          payment_methods = [options[:payment_method]]
          tag_name = 'PaymentMethod'
        when options[:payment_methods] && !options[:payment_method]
          payment_methods = options[:payment_methods]
          tag_name = 'item'
        else
          payment_methods = [options]
          tag_name = 'PaymentMethod'
        end
        [payment_methods, tag_name]
      end

      def build_credit_card_or_check(soap, payment_method)
        case
        when payment_method[:method].kind_of?(ActiveMerchant::Billing::CreditCard)
          build_tag soap, :string, 'CardNumber', payment_method[:method].number
          build_tag soap, :string, 'CardExpiration',
            "#{"%02d" % payment_method[:method].month}#{payment_method[:method].year.to_s[-2..-1]}"
          if options[:billing_address]
            build_tag soap, :string, 'AvsStreet', options[:billing_address][:address1]
            build_tag soap, :string, 'AvsZip', options[:billing_address][:zip]
          end
          build_tag soap, :string, 'CardCode', payment_method[:method].verification_value
        when payment_method[:method].kind_of?(ActiveMerchant::Billing::Check)
          build_tag soap, :string, 'Account', payment_method[:method].account_number
          build_tag soap, :string, 'Routing', payment_method[:method].routing_number
          unless payment_method[:method].account_type.nil?
            build_tag soap, :string, 'AccountType', payment_method[:method].account_type.capitalize
          end
          build_tag soap, :string, 'DriversLicense', options[:drivers_license]
          build_tag soap, :string, 'DriversLicenseState', options[:drivers_license_state]
          build_tag soap, :string, 'RecordType', options[:record_type]
        end
      end

      def build_customer_payment_methods(soap, options)
        payment_methods, tag_name = extract_methods_and_tag(options)
        payment_methods.each do |payment_method|
          soap.tag! tag_name, 'xsi:type' => "ns1:PaymentMethod" do
            build_tag soap, :integer, 'MethodID', payment_method[:method_id]
            build_tag soap, :string, 'MethodType', payment_method[:type]
            build_tag soap, :string, 'MethodName', payment_method[:name]
            build_tag soap, :integer, 'SecondarySort', payment_method[:sort]
            build_credit_card_or_check(soap, payment_method)
          end
        end
      end

      def build_customer_transaction(soap, options)
        soap.Parameters 'xsi:type' => "ns1:CustomerTransactionRequest" do
          build_transaction_detail soap, options
          CUSTOMER_TRANSACTION_REQUEST_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
          build_custom_fields soap, options
          build_line_items soap, options
        end
      end

      # Transaction Helpers ===========================================

      def build_transaction_request_object(soap, options, name='Params')
        soap.tag! name, 'xsi:type' => "ns1:TransactionRequestObject" do
          TRANSACTION_REQUEST_OBJECT_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
          case
          when options[:payment_method] == nil
          when options[:payment_method].kind_of?(ActiveMerchant::Billing::CreditCard)
            build_credit_card_data soap, options
          when options[:payment_method].kind_of?(ActiveMerchant::Billing::Check)
            build_check_data soap, options
          else
            raise ArgumentError, 'options[:payment_method] must be a CreditCard or Check'
          end
          build_transaction_detail soap, options
          build_billing_address soap, options
          build_shipping_address soap, options
          build_recurring_billing soap, options
          build_line_items soap, options
          build_custom_fields soap, options
        end
      end

      def build_transaction_detail(soap, options)
        soap.Details 'xsi:type' => "ns1:TransactionDetail" do
          TRANSACTION_DETAIL_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
          TRANSACTION_DETAIL_MONEY_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], amount(options[k])
          end
        end
      end

      def build_credit_card_data(soap, options)
        soap.CreditCardData 'xsi:type' => "ns1:CreditCardData" do
          build_tag soap, :string, 'CardNumber', options[:payment_method].number
          build_tag soap, :string, 'CardExpiration', build_card_expiration(options)
          if options[:billing_address]
            build_tag soap, :string, 'AvsStreet', options[:billing_address][:address1]
            build_tag soap, :string, 'AvsZip', options[:billing_address][:zip]
          end
          build_tag soap, :string, 'CardCode', options[:payment_method].verification_value
          build_tag soap, :boolean, 'CardPresent', options[:card_present] || false
          CREDIT_CARD_DATA_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
        end
      end

      def build_card_expiration(options)
        month = options[:payment_method].month
        year  = options[:payment_method].year
        unless month.nil? || year.nil?
          "#{"%02d" % month}#{year.to_s[-2..-1]}"
        end
      end

      def build_check_data(soap, options)
        soap.CheckData 'xsi:type' => "ns1:CheckData" do
          build_tag soap, :integer, 'CheckNumber', options[:payment_method].number
          build_tag soap, :string, 'Account', options[:payment_method].account_number
          build_tag soap, :string, 'Routing', options[:payment_method].routing_number
          build_tag soap, :string, 'AccountType', options[:payment_method].account_type.capitalize
          CHECK_DATA_OPTIONS.each do |k,v|
            build_tag soap, v[0], v[1], options[k]
          end
        end
      end

      def build_recurring_billing(soap, options)
        if options[:recurring]
          soap.RecurringBilling 'xsi:type' => "ns1:RecurringBilling" do
            build_tag soap, :double, 'Amount', amount(options[:recurring][:amount])
            build_tag soap, :string, 'Next', options[:recurring][:next].strftime("%Y-%m-%d") if options[:recurring][:next]
            build_tag soap, :string, 'Expire', options[:recurring][:expire].strftime("%Y-%m-%d") if options[:recurring][:expire]
            RECURRING_BILLING_OPTIONS.each do |k,v|
              build_tag soap, v[0], v[1], options[:recurring][k]
            end
          end
        end
      end

      def build_transaction_field_array(soap, options)
        soap.Fields 'SOAP-ENC:arryType' => "xsd:string[#{options[:fields].length}]", 'xsi:type' => 'ns1:stringArray' do
          options[:fields].each do |field|
            build_tag soap, :string, 'item', field
          end
        end
      end

      # General Helpers ===============================================

      def build_billing_address(soap, options)
        if options[:billing_address]
          if options[:billing_address][:name]
            name = options[:billing_address][:name].split(nil,2) # divide name
            options[:billing_address][:first_name], options[:billing_address][:last_name] = name[0], name[1]
          end
          soap.BillingAddress 'xsi:type' => "ns1:Address" do
            ADDRESS_OPTIONS.each do |k,v|
              build_tag soap, v[0], v[1], options[:billing_address][k]
            end
          end
        end
      end

      def build_shipping_address(soap, options)
        if options[:shipping_address]
          if options[:shipping_address][:name]
            name = options[:shipping_address][:name].split(nil,2) # divide name
            options[:shipping_address][:first_name], options[:shipping_address][:last_name] = name[0], name[1]
          end
          soap.ShippingAddress 'xsi:type' => "ns1:Address" do
            ADDRESS_OPTIONS.each do |k,v|
              build_tag soap, v[0], v[1], options[:shipping_address][k]
            end
          end
        end
      end

      def build_line_items(soap, options) # TODO
      end

      def build_custom_fields(soap, options) # TODO
      end

      # Request =======================================================

      def commit(action, request)
        url = test? ? test_url : live_url

        begin
          soap = ssl_post(url, request, "Content-Type" => "text/xml")
        rescue ActiveMerchant::ResponseError => error
          soap = error.response.body
        end

        build_response(action, soap)
      end

      def build_response(action, soap)
        response_params, success, message, authorization, avs, cvv = parse(action, soap)

        response_params.merge!('soap_response' => soap) if @options[:soap_response]

        Response.new(
          success,
          message,
          response_params,
          :test => test?,
          :authorization => authorization,
          :avs_result => avs_from(avs),
          :cvv_result => cvv
        )
      end

      def avs_from(avs)
        avs_params = { :code => avs }
        avs_params.merge!(:message => AVS_CUSTOM_MESSAGES[avs]) if AVS_CUSTOM_MESSAGES.key?(avs)
        avs_params
      end

      def parse(action, soap)
        xml = REXML::Document.new(soap)
        root = REXML::XPath.first(xml, "//SOAP-ENV:Body")
        response = root ? parse_element(root[0]) : { :response => soap }

        success, message, authorization, avs, cvv = false, FAILURE_MESSAGE, nil, nil, nil

        fault = (!response) || (response.length < 1) || response.has_key?('faultcode')
        return [response, success, response['faultstring'], authorization, avs, cvv] if fault

        if response.respond_to?(:[]) && p = response["#{action}_return"]
          if p.respond_to?(:key?) && p.key?('result_code')
            success = p['result_code'] == 'A' ? true : false
            authorization = p['ref_num']
            avs = AVS_RESULTS[p['avs_result_code']]
            cvv = p['card_code_result_code']
          else
            success = true
          end
          message = case action
          when :get_customer_payment_methods
            p['item']
          when :get_transaction_custom
            items = p['item'].kind_of?(Array) ? p['item'] : [p['item']]
            items.inject({}) { |hash, item| hash[item['field']] = item['value']; hash }
          else
            p
          end
        elsif response.respond_to?(:[]) && p = response[:response]
          message = p # when response is html
        end

        [response, success, message, authorization, avs, cvv]
      end

      def parse_element(node)
        if node.has_elements?
          response = {}
          node.elements.each do |e|
            key = e.name.underscore
            value = parse_element(e)
            if response.has_key?(key)
              if response[key].is_a?(Array)
                response[key].push(value)
              else
                response[key] = [response[key], value]
              end
            else
              response[key] = parse_element(e)
            end
          end
        else
          response = node.text
        end

        response
      end

    end
  end
end

