require File.dirname(__FILE__) + '/orbital/orbital_soft_descriptors'
require File.dirname(__FILE__) + '/orbital/avs_result'
require File.dirname(__FILE__) + '/orbital/cvv_result'
require "rexml/document"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on Orbital, visit the {integration center}[http://download.chasepaymentech.com]
    #
    # ==== Authentication Options
    #
    # The Orbital Gateway supports two methods of authenticating incoming requests:
    # Source IP authentication and Connection Username/Password authentication
    #
    # In addition, these IP addresses/Connection Usernames must be affiliated with the Merchant IDs
    # for which the client should be submitting transactions.
    #
    # This does allow Third Party Hosting service organizations presenting on behalf of other
    # merchants to submit transactions.  However, each time a new customer is added, the
    # merchant or Third-Party hosting organization needs to ensure that the new Merchant IDs
    # or Chain IDs are affiliated with the hosting companies IPs or Connection Usernames.
    #
    # If the merchant expects to have more than one merchant account with the Orbital
    # Gateway, it should have its IP addresses/Connection Usernames affiliated at the Chain
    # level hierarchy within the Orbital Gateway.  Each time a new merchant ID is added, as
    # long as it is placed within the same Chain, it will simply work.  Otherwise, the additional
    # MIDs will need to be affiliated with the merchant IPs or Connection Usernames respectively.
    # For example, we generally affiliate all Salem accounts [BIN 000001] with
    # their Company Number [formerly called MA #] number so all MIDs or Divisions under that
    # Company will automatically be affiliated.

    class OrbitalGateway < Gateway
      API_VERSION = "5.6"

      POST_HEADERS = {
        "MIME-Version" => "1.1",
        "Content-Type" => "application/PTI56",
        "Content-transfer-encoding" => "text",
        "Request-number" => '1',
        "Document-type" => "Request",
        "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }

      SUCCESS = '0'

      APPROVED = [
        '00', # Approved
        '08', # Approved authorization, honor with ID
        '11', # Approved authorization, VIP approval
        '24', # Validated
        '26', # Pre-noted
        '27', # No reason to decline
        '28', # Received and stored
        '29', # Provided authorization
        '31', # Request received
        '32', # BIN alert
        '34', # Approved for partial
        '91', # Approved low fraud
        '92', # Approved medium fraud
        '93', # Approved high fraud
        '94', # Approved fraud service unavailable
        'E7', # Stored
        'PA'  # Partial approval
      ]

      class_attribute :secondary_test_url, :secondary_live_url

      self.test_url = "https://orbitalvar1.paymentech.net/authorize"
      self.secondary_test_url = "https://orbitalvar2.paymentech.net/authorize"

      self.live_url = "https://orbital1.paymentech.net/authorize"
      self.secondary_live_url = "https://orbital2.paymentech.net/authorize"

      self.supported_countries = ["US", "CA"]
      self.default_currency = "CAD"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.display_name = 'Orbital Paymentech'
      self.homepage_url = 'http://chasepaymentech.com/'

      self.money_format = :cents

      AVS_SUPPORTED_COUNTRIES = ['US', 'CA', 'UK', 'GB']

      CURRENCY_CODES = {
        "AUD" => '036',
        "CAD" => '124',
        "CZK" => '203',
        "DKK" => '208',
        "HKD" => '344',
        "ICK" => '352',
        "JPY" => '392',
        "MXN" => '484',
        "NZD" => '554',
        "NOK" => '578',
        "SGD" => '702',
        "SEK" => '752',
        "CHF" => '756',
        "GBP" => '826',
        "USD" => '840',
        "EUR" => '978'
      }

      CURRENCY_EXPONENTS = {
        "AUD" => '2',
        "CAD" => '2',
        "CZK" => '2',
        "DKK" => '2',
        "HKD" => '2',
        "ICK" => '2',
        "JPY" => '0',
        "MXN" => '2',
        "NZD" => '2',
        "NOK" => '2',
        "SGD" => '2',
        "SEK" => '2',
        "CHF" => '2',
        "GBP" => '2',
        "USD" => '2',
        "EUR" => '2'
      }

      # INDUSTRY TYPES
      ECOMMERCE_TRANSACTION = 'EC'
      RECURRING_PAYMENT_TRANSACTION = 'RC'
      MAIL_ORDER_TELEPHONE_ORDER_TRANSACTION = 'MO'
      INTERACTIVE_VOICE_RESPONSE = 'IV'
      # INTERACTIVE_VOICE_RESPONSE = 'IN'

      # Auth Only No Capture
      AUTH_ONLY = 'A'
      # AC - Auth and Capture = 'AC'
      AUTH_AND_CAPTURE = 'AC'
      # F  - Force Auth No Capture and no online authorization = 'F'
      FORCE_AUTH_ONLY = 'F'
      # FR - Force Auth No Capture and no online authorization = 'FR'
      # FC - Force Auth and Capture no online authorization = 'FC'
      FORCE_AUTH_AND_CAPTURE = 'FC'
      # Refund and Capture no online authorization
      REFUND = 'R'

      # Tax Inds
      TAX_NOT_PROVIDED = 0
      TAX_INCLUDED     = 1
      NON_TAXABLE_TRANSACTION = 2

      # Customer Profile Actions
      CREATE   = 'C'
      RETRIEVE = 'R'
      UPDATE   = 'U'
      DELETE   = 'D'

      RECURRING = 'R'
      DEFERRED  = 'D'

      # Status
      # Profile Status Flag
      # This field is used to set the status of a Customer Profile.
      ACTIVE   = 'A'
      INACTIVE = 'I'
      MANUAL_SUSPEND = 'MS'

      # CustomerProfileOrderOverrideInd
      # Defines if any Order Data can be pre-populated from
      # the Customer Reference Number (CustomerRefNum)
      NO_MAPPING_TO_ORDER_DATA = 'NO'
      USE_CRN_FOR_ORDER_ID     = 'OI'
      USE_CRN_FOR_COMMENTS     = 'OD'
      USE_CRN_FOR_ORDER_ID_AND_COMMENTS = 'OA'

      #  CustomerProfileFromOrderInd
      # Method to use to Generate the Customer Profile Number
      # When Customer Profile Action Type = Create, defines
      # what the Customer Profile Number will be:
      AUTO_GENERATE        = 'A' # Auto-Generate the CustomerRefNum
      USE_CUSTOMER_REF_NUM = 'S' # Use CustomerRefNum field
      USE_ORDER_ID         = 'O' #  Use OrderID field
      USE_COMMENTS         = 'D' #  Use Comments field

      SENSITIVE_FIELDS = [:account_num]

      def initialize(options = {})
        requires!(options, :merchant_id)
        requires!(options, :login, :password) unless options[:ip_authentication]
        super
      end

      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml(AUTH_ONLY, money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency])
          add_address(xml, creditcard, options)
          if @options[:customer_profiles]
            add_customer_data(xml, options)
            add_managed_billing(xml, options)
          end
        end
        commit(order, :authorize, options[:trace_number])
      end

      # AC – Authorization and Capture
      def purchase(money, creditcard, options = {})
        order = build_new_order_xml(AUTH_AND_CAPTURE, money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency])
          add_address(xml, creditcard, options)
          if @options[:customer_profiles]
            add_customer_data(xml, options)
            add_managed_billing(xml, options)
          end
        end
        commit(order, :purchase, options[:trace_number])
      end

      # MFC - Mark For Capture
      def capture(money, authorization, options = {})
        commit(build_mark_for_capture_xml(money, authorization, options), :capture)
      end

      # R – Refund request
      def refund(money, authorization, options = {})
        order = build_new_order_xml(REFUND, money, options.merge(:authorization => authorization)) do |xml|
          add_refund(xml, options[:currency])
          xml.tag! :CustomerRefNum, options[:customer_ref_num] if @options[:customer_profiles] && options[:profile_txn]
        end
        commit(order, :refund, options[:trace_number])
      end

      def credit(money, authorization, options= {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def void(authorization, options = {}, deprecated = {})
        if(!options.kind_of?(Hash))
          ActiveMerchant.deprecated("Calling the void method with an amount parameter is deprecated and will be removed in a future version.")
          return void(options, deprecated.merge(:amount => authorization))
        end

        order = build_void_request_xml(authorization, options)
        commit(order, :void, options[:trace_number])
      end


      # ==== Customer Profiles
      # :customer_ref_num should be set unless your happy with Orbital providing one
      #
      # :customer_profile_order_override_ind can be set to map
      # the CustomerRefNum to OrderID or Comments. Defaults to 'NO' - no mapping
      #
      #   'NO' - No mapping to order data
      #   'OI' - Use <CustomerRefNum> for <OrderID>
      #   'OD' - Use <CustomerRefNum> for <Comments>
      #   'OA' - Use <CustomerRefNum> for <OrderID> and <Comments>
      #
      # :order_default_description can be set optionally. 64 char max.
      #
      # :order_default_amount can be set optionally. integer as cents.
      #
      # :status defaults to Active
      #
      #   'A' - Active
      #   'I' - Inactive
      #   'MS'  - Manual Suspend

      def add_customer_profile(creditcard, options = {})
        options.merge!(:customer_profile_action => CREATE)
        order = build_customer_request_xml(creditcard, options)
        commit(order, :add_customer_profile)
      end

      def update_customer_profile(creditcard, options = {})
        options.merge!(:customer_profile_action => UPDATE)
        order = build_customer_request_xml(creditcard, options)
        commit(order, :update_customer_profile)
      end

      def retrieve_customer_profile(customer_ref_num)
        options = {:customer_profile_action => RETRIEVE, :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order, :retrieve_customer_profile)
      end

      def delete_customer_profile(customer_ref_num)
        options = {:customer_profile_action => DELETE, :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order, :delete_customer_profile)
      end

      private

      def authorization_string(*args)
        args.compact.join(";")
      end

      def split_authorization(authorization)
        authorization.split(';')
      end

      def add_customer_data(xml, options)
        if options[:profile_txn]
          xml.tag! :CustomerRefNum, options[:customer_ref_num]
        else
          if options[:customer_ref_num]
            xml.tag! :CustomerProfileFromOrderInd, USE_CUSTOMER_REF_NUM
            xml.tag! :CustomerRefNum, options[:customer_ref_num]
          else
            xml.tag! :CustomerProfileFromOrderInd, AUTO_GENERATE
          end
          xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || NO_MAPPING_TO_ORDER_DATA
        end
      end

      def add_soft_descriptors(xml, soft_desc)
        xml.tag! :SDMerchantName, soft_desc.merchant_name             if soft_desc.merchant_name
        xml.tag! :SDProductDescription, soft_desc.product_description if soft_desc.product_description
        xml.tag! :SDMerchantCity, soft_desc.merchant_city             if soft_desc.merchant_city
        xml.tag! :SDMerchantPhone, soft_desc.merchant_phone           if soft_desc.merchant_phone
        xml.tag! :SDMerchantURL, soft_desc.merchant_url               if soft_desc.merchant_url
        xml.tag! :SDMerchantEmail, soft_desc.merchant_email           if soft_desc.merchant_email
      end

      def add_address(xml, creditcard, options)
        if(address = (options[:billing_address] || options[:address]))
          avs_supported = AVS_SUPPORTED_COUNTRIES.include?(address[:country].to_s)

          if avs_supported
            xml.tag! :AVSzip,       (address[:zip] ? address[:zip].to_s[0..9] : nil)
            xml.tag! :AVSaddress1,  (address[:address1] ? address[:address1][0..29] : nil)
            xml.tag! :AVSaddress2,  (address[:address2] ? address[:address2][0..29] : nil)
            xml.tag! :AVScity,      (address[:city] ? address[:city][0..19] : nil)
            xml.tag! :AVSstate,     address[:state]
            xml.tag! :AVSphoneNum,  (address[:phone] ? address[:phone].scan(/\d/).join.to_s[0..13] : nil)
          end
          # can't look in billing address?
          xml.tag! :AVSname, ((creditcard && creditcard.name) ? creditcard.name[0..29] : nil)
          xml.tag! :AVScountryCode, (avs_supported ? address[:country] : '')

          # Needs to come after AVScountryCode
          add_destination_address(xml, address) if avs_supported
        end
      end

      def add_destination_address(xml, address)
        if address[:dest_zip]
          xml.tag! :AVSDestzip,      (address[:dest_zip] ? address[:dest_zip].to_s[0..9] : nil)
          xml.tag! :AVSDestaddress1, (address[:dest_address1] ? address[:dest_address1][0..29] : nil)
          xml.tag! :AVSDestaddress2, (address[:dest_address2] ? address[:dest_address2][0..29] : nil)
          xml.tag! :AVSDestcity,     (address[:dest_city] ? address[:dest_city][0..19] : nil)
          xml.tag! :AVSDeststate,    address[:dest_state]
          xml.tag! :AVSDestphoneNum, (address[:dest_phone] ? address[:dest_phone].scan(/\d/).join.to_s[0..13] : nil)

          xml.tag! :AVSDestname,        (address[:dest_name] ? address[:dest_name][0..29] : nil)
          xml.tag! :AVSDestcountryCode, address[:dest_country]
        end
      end

      # For Profile requests
      def add_customer_address(xml, options)
        if(address = (options[:billing_address] || options[:address]))
          xml.tag! :CustomerAddress1, (address[:address1] ? address[:address1][0..29] : nil)
          xml.tag! :CustomerAddress2, (address[:address2] ? address[:address2][0..29] : nil)
          xml.tag! :CustomerCity, (address[:city] ? address[:city][0..19] : nil)
          xml.tag! :CustomerState, address[:state]
          xml.tag! :CustomerZIP, (address[:zip] ? address[:zip].to_s[0..9] : nil)
          xml.tag! :CustomerEmail, address[:email].to_s[0..49] if address[:email]
          xml.tag! :CustomerPhone, (address[:phone] ? address[:phone].scan(/\d/).join.to_s : nil)
          xml.tag! :CustomerCountryCode, (address[:country] ? address[:country][0..1] : nil)
        end
      end

      def add_creditcard(xml, creditcard, currency=nil)
        unless creditcard.nil?
          xml.tag! :AccountNum, creditcard.number
          xml.tag! :Exp, expiry_date(creditcard)
        end

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, currency_exponents(currency)

        # If you are trying to collect a Card Verification Number
        # (CardSecVal) for a Visa or Discover transaction, pass one of these values:
        #   1 Value is Present
        #   2 Value on card but illegible
        #   9 Cardholder states data not available
        # If the transaction is not a Visa or Discover transaction:
        #   Null-fill this attribute OR
        #   Do not submit the attribute at all.
        # - http://download.chasepaymentech.com/docs/orbital/orbital_gateway_xml_specification.pdf
        unless creditcard.nil?
          if %w( visa discover ).include?(creditcard.brand)
            xml.tag! :CardSecValInd, (creditcard.verification_value? ? '1' : '9')
          end
          xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
        end
      end

      def add_refund(xml, currency=nil)
        xml.tag! :AccountNum, nil

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, currency_exponents(currency)
      end

      def add_managed_billing(xml, options)
        if mb = options[:managed_billing]
          ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

          # default to recurring (R).  Other option is deferred (D).
          xml.tag! :MBType, mb[:type] || RECURRING
          # default to Customer Reference Number
          xml.tag! :MBOrderIdGenerationMethod,     mb[:order_id_generation_method] || 'IO'
          # By default use MBRecurringEndDate, set to N.
          # MMDDYYYY
          xml.tag! :MBRecurringStartDate,          mb[:start_date].scan(/\d/).join.to_s if mb[:start_date]
          # MMDDYYYY
          xml.tag! :MBRecurringEndDate,            mb[:end_date].scan(/\d/).join.to_s if mb[:end_date]
          # By default listen to any value set in MBRecurringEndDate.
          xml.tag! :MBRecurringNoEndDateFlag,      mb[:no_end_date_flag] || 'N' # 'Y' || 'N' (Yes or No).
          xml.tag! :MBRecurringMaxBillings,        mb[:max_billings]       if mb[:max_billings]
          xml.tag! :MBRecurringFrequency,          mb[:frequency]          if mb[:frequency]
          xml.tag! :MBDeferredBillDate,            mb[:deferred_bill_date] if mb[:deferred_bill_date]
          xml.tag! :MBMicroPaymentMaxDollarValue,  mb[:max_dollar_value]   if mb[:max_dollar_value]
          xml.tag! :MBMicroPaymentMaxBillingDays,  mb[:max_billing_days]   if mb[:max_billing_days]
          xml.tag! :MBMicroPaymentMaxTransactions, mb[:max_transactions]   if mb[:max_transactions]
        end
      end

      def parse(body)
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//Response") ||
               REXML::XPath.first(xml, "//ErrorResponse")
        if root
          root.elements.to_a.each do |node|
            recurring_parse_element(response, node)
          end
        end

        response.delete_if { |k,_| SENSITIVE_FIELDS.include?(k) }
      end

      def recurring_parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def commit(order, message_type, trace_number=nil)
        headers = POST_HEADERS.merge("Content-length" => order.size.to_s)
        headers.merge!( "Trace-number" => trace_number.to_s,
                        "Merchant-Id" => @options[:merchant_id] ) if @options[:retry_logic] && trace_number
        request = lambda{|url| parse(ssl_post(url, order, headers))}

        # Failover URL will be attempted in the event of a connection error
        response = begin
          request.call(remote_url)
        rescue ConnectionError
          request.call(remote_url(:secondary))
        end

        Response.new(success?(response, message_type), message_from(response), response,
          {
             :authorization => authorization_string(response[:tx_ref_num], response[:order_id]),
             :test => self.test?,
             :avs_result => OrbitalGateway::AVSResult.new(response[:avs_resp_code]),
             :cvv_result => OrbitalGateway::CVVResult.new(response[:cvv2_resp_code])
          }
        )
      end

      def remote_url(url=:primary)
        if url == :primary
          (self.test? ? self.test_url : self.live_url)
        else
          (self.test? ? self.secondary_test_url : self.secondary_live_url)
        end
      end

      def success?(response, message_type)
        if [:refund, :void].include?(message_type)
          response[:proc_status] == SUCCESS
        elsif response[:customer_profile_action]
          response[:profile_proc_status] == SUCCESS
        else
          response[:proc_status] == SUCCESS &&
          APPROVED.include?(response[:resp_code])
        end
      end

      def message_from(response)
        response[:resp_msg] || response[:status_msg] || response[:customer_profile_message]
      end

      def ip_authentication?
        @options[:ip_authentication] == true
      end

      def build_new_order_xml(action, money, parameters = {})
        requires!(parameters, :order_id)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :NewOrder do
            add_xml_credentials(xml)
            # EC - Ecommerce transaction
            # RC - Recurring Payment transaction
            # MO - Mail Order Telephone Order transaction
            # IV - Interactive Voice Response
            # IN - Interactive Voice Response
            xml.tag! :IndustryType, parameters[:industry_type] || ECOMMERCE_TRANSACTION
            # A  - Auth Only No Capture
            # AC - Auth and Capture
            # F  - Force Auth No Capture and no online authorization
            # FR - Force Auth No Capture and no online authorization
            # FC - Force Auth and Capture no online authorization
            # R  - Refund and Capture no online authorization
            xml.tag! :MessageType, action
            add_bin_merchant_and_terminal(xml, parameters)

            yield xml if block_given?

            xml.tag! :OrderID, format_order_id(parameters[:order_id])
            xml.tag! :Amount, amount(money)
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]

            # CustomerAni, AVSPhoneType and AVSDestPhoneType could be added here.

            if parameters[:soft_descriptors].is_a?(OrbitalSoftDescriptors)
              add_soft_descriptors(xml, parameters[:soft_descriptors])
            end

            set_recurring_ind(xml, parameters)

            # Append Transaction Reference Number at the end for Refund transactions
            if action == REFUND
              tx_ref_num, _ = split_authorization(parameters[:authorization])
              xml.tag! :TxRefNum, tx_ref_num
            end
          end
        end
        xml.target!
      end

      # For Canadian transactions on PNS Tampa on New Order
      # RF - First Recurring Transaction
      # RS - Subsequent Recurring Transactions
      def set_recurring_ind(xml, parameters)
        if parameters[:recurring_ind]
          raise "RecurringInd must be set to either \"RF\" or \"RS\"" unless %w(RF RS).include?(parameters[:recurring_ind])
          xml.tag! :RecurringInd, parameters[:recurring_ind]
        end
      end

      def build_mark_for_capture_xml(money, authorization, parameters = {})
        tx_ref_num, order_id = split_authorization(authorization)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :MarkForCapture do
            add_xml_credentials(xml)
            xml.tag! :OrderID, format_order_id(order_id)
            xml.tag! :Amount, amount(money)
            add_bin_merchant_and_terminal(xml, parameters)
            xml.tag! :TxRefNum, tx_ref_num
          end
        end
        xml.target!
      end

      def build_void_request_xml(authorization, parameters = {})
        tx_ref_num, order_id = split_authorization(authorization)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :Reversal do
            add_xml_credentials(xml)
            xml.tag! :TxRefNum, tx_ref_num
            xml.tag! :TxRefIdx, parameters[:transaction_index]
            xml.tag! :AdjustedAmt, parameters[:amount] # setting adjusted amount to nil will void entire amount
            xml.tag! :OrderID, format_order_id(order_id || parameters[:order_id])
            add_bin_merchant_and_terminal(xml, parameters)
            xml.tag! :ReversalRetryNumber, parameters[:reversal_retry_number] if parameters[:reversal_retry_number]
            xml.tag! :OnlineReversalInd,   parameters[:online_reversal_ind]   if parameters[:online_reversal_ind]
          end
        end
        xml.target!
      end

      def currency_code(currency)
        CURRENCY_CODES[(currency || self.default_currency)].to_s
      end

      def currency_exponents(currency)
        CURRENCY_EXPONENTS[(currency || self.default_currency)].to_s
      end

      def expiry_date(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def bin
        @options[:bin] || (salem_mid? ? '000001' : '000002')
      end

      def xml_envelope
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml
      end

      def add_xml_credentials(xml)
        unless ip_authentication?
          xml.tag! :OrbitalConnectionUsername, @options[:login]
          xml.tag! :OrbitalConnectionPassword, @options[:password]
        end
      end

      def add_bin_merchant_and_terminal(xml, parameters)
        xml.tag! :BIN, bin
        xml.tag! :MerchantID, @options[:merchant_id]
        xml.tag! :TerminalID, parameters[:terminal_id] || '001'
      end

      def salem_mid?
        @options[:merchant_id].length == 6
      end

      # The valid characters include:
      #
      # 1. all letters and digits
      # 2. - , $ @ & and a space character, though the space character cannot be the leading character
      # 3. PINless Debit transactions can only use uppercase and lowercase alpha (A-Z, a-z) and numeric (0-9)
      def format_order_id(order_id)
        illegal_characters = /[^,$@\- \w]/
        order_id = order_id.to_s.gsub(/\./, '-')
        order_id.gsub!(illegal_characters, '')
        order_id[0...22]
      end

      def build_customer_request_xml(creditcard, options = {})
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :Profile do
            xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
            xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
            xml.tag! :CustomerBin, bin
            xml.tag! :CustomerMerchantID, @options[:merchant_id]
            xml.tag! :CustomerName, creditcard.name if creditcard
            xml.tag! :CustomerRefNum, options[:customer_ref_num] if options[:customer_ref_num]

            add_customer_address(xml, options)

            xml.tag! :CustomerProfileAction, options[:customer_profile_action] # C, R, U, D
            # NO No mapping to order data
            # OI Use <CustomerRefNum> for <OrderID>
            # OD Use <CustomerReferNum> for <Comments>
            # OA Use <CustomerRefNum> for <OrderID> and <Comments>
            xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || NO_MAPPING_TO_ORDER_DATA

            if options[:customer_profile_action] == CREATE
              # A Auto-Generate the CustomerRefNum
              # S Use CustomerRefNum field
              # O Use OrderID field
              # D Use Comments field
              xml.tag! :CustomerProfileFromOrderInd, (options[:customer_ref_num] ? USE_CUSTOMER_REF_NUM : AUTO_GENERATE)
            end

            xml.tag! :OrderDefaultDescription, options[:order_default_description][0..63] if options[:order_default_description]
            xml.tag! :OrderDefaultAmount, options[:order_default_amount] if options[:order_default_amount]

            if [CREATE, UPDATE].include? options[:customer_profile_action]
              xml.tag! :CustomerAccountType, 'CC' # Only credit card supported
              xml.tag! :Status, options[:status] || ACTIVE # Active
            end

            xml.tag! :CCAccountNum, creditcard.number if creditcard
            xml.tag! :CCExpireDate, creditcard.expiry_date.expiration.strftime("%m%y") if creditcard

            # This has to come after CCExpireDate.
            add_managed_billing(xml, options)
          end
        end
        xml.target!
      end
    end
  end
end
