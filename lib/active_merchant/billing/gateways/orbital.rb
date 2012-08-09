require File.dirname(__FILE__) + '/orbital/orbital_soft_descriptors.rb'
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
        "MIME-Version" => "1.0",
        "Content-Type" => "Application/PTI46",
        "Content-transfer-encoding" => "text",
        "Request-number" => '1',
        "Document-type" => "Request",
        "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }

      SUCCESS, APPROVED = '0', '00'

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

      def initialize(options = {})
        requires!(options, :merchant_id)
        requires!(options, :login, :password) unless options[:ip_authentication]
        @options = options
        super
      end

      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml('A', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency]) unless creditcard.nil? && options[:profile_txn]
          add_address(xml, creditcard, options)
          add_customer_data(xml, options) if @options[:customer_profiles]
        end
        commit(order)
      end

      # AC – Authorization and Capture
      def purchase(money, creditcard, options = {})
        order = build_new_order_xml('AC', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency]) unless creditcard.nil? && options[:profile_txn]
          add_address(xml, creditcard, options)
          add_customer_data(xml, options) if @options[:customer_profiles]
        end
        commit(order)
      end

      # MFC - Mark For Capture
      def capture(money, authorization, options = {})
        commit(build_mark_for_capture_xml(money, authorization, options))
      end

      # R – Refund request
      def refund(money, authorization, options = {})
        order = build_new_order_xml('R', money, options.merge(:authorization => authorization)) do |xml|
          add_refund(xml, options[:currency])
          xml.tag! :CustomerRefNum, options[:customer_ref_num] if @options[:customer_profiles] && options[:profile_txn]
        end
        commit(order)
      end

      def credit(money, authorization, options= {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      # setting money to nil will perform a full void
      def void(money, authorization, options = {})
        order = build_void_request_xml(money, authorization, options)
        commit(order)
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
        options.merge!(:customer_profile_action => 'C')
        order = build_customer_request_xml(creditcard, options)
        commit(order)
      end

      def update_customer_profile(creditcard, options = {})
        options.merge!(:customer_profile_action => 'U')
        order = build_customer_request_xml(creditcard, options)
        commit(order)
      end

      def retrieve_customer_profile(customer_ref_num)
        options = {:customer_profile_action => 'R', :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order)
      end

      def delete_customer_profile(customer_ref_num)
        options = {:customer_profile_action => 'D', :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order)
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
            xml.tag! :CustomerProfileFromOrderInd, 'S'
            xml.tag! :CustomerRefNum, options[:customer_ref_num]
          else
            xml.tag! :CustomerProfileFromOrderInd, 'A'
          end
          xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || 'NO'
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
        if address = options[:billing_address] || options[:address]
          avs_supported = AVS_SUPPORTED_COUNTRIES.include?(address[:country].to_s)

          if avs_supported
            xml.tag! :AVSzip, address[:zip]
            xml.tag! :AVSaddress1, address[:address1]
            xml.tag! :AVSaddress2, address[:address2]
            xml.tag! :AVScity, address[:city]
            xml.tag! :AVSstate, address[:state]
            xml.tag! :AVSphoneNum, address[:phone] ? address[:phone].scan(/\d/).join.to_s : nil
          end
          xml.tag! :AVSname, creditcard.name
          xml.tag! :AVScountryCode, avs_supported ? address[:country] : ''
        end
      end

      # For Profile requests
      def add_customer_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.tag! :CustomerAddress1, address[:address1]
          xml.tag! :CustomerAddress2, address[:address2]
          xml.tag! :CustomerCity, address[:city]
          xml.tag! :CustomerState, address[:state]
          xml.tag! :CustomerZIP, address[:zip]
          xml.tag! :CustomerPhone, address[:phone] ? address[:phone].scan(/\d/).to_s : nil
          xml.tag! :CustomerCountryCode, address[:country]
        end
      end

      def add_creditcard(xml, creditcard, currency=nil)
        xml.tag! :AccountNum, creditcard.number
        xml.tag! :Exp, expiry_date(creditcard)

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.

        # If you are trying to collect a Card Verification Number
        # (CardSecVal) for a Visa or Discover transaction, pass one of these values:
        #   1 Value is Present
        #   2 Value on card but illegible
        #   9 Cardholder states data not available
        # If the transaction is not a Visa or Discover transaction:
        #   Null-fill this attribute OR
        #   Do not submit the attribute at all.
        # - http://download.chasepaymentech.com/docs/orbital/orbital_gateway_xml_specification.pdf
        if %w( visa discover ).include?(creditcard.brand)
          xml.tag! :CardSecValInd, creditcard.verification_value? ? '1' : '9'
        end
        xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
      end

      def add_refund(xml, currency=nil)
        xml.tag! :AccountNum, nil

        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
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
        response
      end

      def recurring_parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def commit(order)
        headers = POST_HEADERS.merge("Content-length" => order.size.to_s)
        request = lambda {return parse(ssl_post(remote_url, order, headers))}

        # Failover URL will be used in the event of a connection error
        begin response = request.call; rescue ConnectionError; retry end

        Response.new(success?(response), message_from(response), response,
          {
             :authorization => authorization_string(response[:tx_ref_num], response[:order_id]),
             :test => self.test?,
             :avs_result => {:code => response[:avs_resp_code]},
             :cvv_result => response[:cvv2_resp_code]
          }
        )
      end

      def remote_url
        unless $!.class == ActiveMerchant::ConnectionError
          self.test? ? self.test_url : self.live_url
        else
          self.test? ? self.secondary_test_url : self.secondary_live_url
        end
      end

      def success?(response)
        if response[:message_type] == "R"
          response[:proc_status] == SUCCESS
        elsif response[:customer_profile_action]
          response[:profile_proc_status] == SUCCESS
        else
          response[:proc_status] == SUCCESS &&
          response[:resp_code] == APPROVED
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
            xml.tag! :IndustryType, parameters[:industry_type] || "EC"
            xml.tag! :MessageType, action
            add_bin_merchant_and_terminal(xml, parameters)

            yield xml if block_given?

            xml.tag! :OrderID, format_order_id(parameters[:order_id])
            xml.tag! :Amount, amount(money)
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]

            if parameters[:soft_descriptors].is_a?(OrbitalSoftDescriptors)
              add_soft_descriptors(xml, parameters[:soft_descriptors])
            end

            set_recurring_ind(xml, parameters)

            # Append Transaction Reference Number at the end for Refund transactions
            if action == "R"
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

      def build_void_request_xml(money, authorization, parameters = {})
        tx_ref_num, order_id = split_authorization(authorization)
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :Reversal do
            add_xml_credentials(xml)
            xml.tag! :TxRefNum, tx_ref_num
            xml.tag! :TxRefIdx, parameters[:transaction_index]
            xml.tag! :AdjustedAmt, amount(money)
            xml.tag! :OrderID, format_order_id(order_id || parameters[:order_id])
            add_bin_merchant_and_terminal(xml, parameters)
          end
        end
        xml.target!
      end

      def currency_code(currency)
        CURRENCY_CODES[(currency || self.default_currency)].to_s
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
        xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
        xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
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
            xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || 'NO'

            if options[:customer_profile_action] == 'C'
              xml.tag! :CustomerProfileFromOrderInd, options[:customer_ref_num] ? 'S' : 'A'
            end

            xml.tag! :OrderDefaultDescription, options[:order_default_description][0..63] if options[:order_default_description]
            xml.tag! :OrderDefaultAmount, options[:order_default_amount] if options[:order_default_amount]

            if ['C', 'U'].include? options[:customer_profile_action]
              xml.tag! :CustomerAccountType, 'CC' # Only credit card supported
              xml.tag! :Status, options[:status] || 'A' # Active
            end

            xml.tag! :CCAccountNum, creditcard.number if creditcard
            xml.tag! :CCExpireDate, creditcard.expiry_date.expiration.strftime("%m%y") if creditcard
          end
        end
        xml.target!
      end
    end
  end
end
