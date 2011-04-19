module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecureNetGateway < Gateway

      API_VERSION = "4.0"

      TRANSACTIONS = {
        :auth_only                      => "0000",  #
        :partial_auth_only              => "0001",
        :auth_capture                   => "0100",  #
        :partial_auth_capture           => "0101",
        :prior_auth_capture             => "0200",
        :capture_only                   => "0300",  #
        :void                           => "0400",  #
        :partial_void                   => "0401",
        :credit                         => "0500",  #
        :credit_authonly                => "0501",
        :credit_priorauthcapture        => "0502",
        :force_credit                   => "0600",
        :force_credit_authonly          => "0601",
        :force_credit_priorauthcapture  => "0602",
        :verification                   => "0700",
        :auth_increment                 => "0800",
        :issue                          => "0900",
        :activate                       => "0901",
        :redeem                         => "0902",
        :redeem_partial                 => "0903",
        :deactivate                     => "0904",
        :reactivate                     => "0905",
        :inquiry_balance                => "0906"
      }

      XML_ATTRIBUTES = { 'xmlns' => "http://gateway.securenet.com/API/Contracts",
                         'xmlns:i' => "http://www.w3.org/2001/XMLSchema-instance"
                       }
      NIL_ATTRIBUTE = { 'i:nil' => "true" }

#      SUCCESS = "true"
#      SENSITIVE_FIELDS = [ :verification_str2, :expiry_date, :card_number ]

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.securenet.com/'
      self.display_name = 'SecureNet'
#      self.wiredump_device = STDOUT

#      TEST_URL = 'https://certify.securenet.com/api/Gateway.svc'
      TEST_URL = 'https://certify.securenet.com/API/gateway.svc/webHttp/ProcessTransaction'
      LIVE_URL = 'https://gateway.securenet.com/api/Gateway.svc'

      APPROVED, DECLINED, ERROR = 1, 2, 3

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 0, 2, 3
      AVS_RESULT_CODE, CARD_CODE_RESPONSE_CODE, TRANSACTION_ID  = 5, 6, 8

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        commit(build_sale_or_authorization_request(creditcard, options, :auth_only), money)
      end

      def purchase(money, creditcard, options = {})
        commit(build_sale_or_authorization_request(creditcard, options, :auth_capture), money)
      end

      def capture(money, creditcard, authorization, options = {})
        commit(build_capture_request(authorization, creditcard, options, :prior_auth_capture), money)
      end

      def void(money, creditcard, authorization, options = {})
        commit(build_void_request(authorization, creditcard, options, :void), money)
      end

      def credit(money, creditcard, authorization, options = {})
        commit(build_credit_request(authorization, creditcard, options, :credit), money)
      end

      private
      def commit(request, money)
        xml = build_request(request, money)
        data = ssl_post(TEST_URL, xml, "Content-Type" => "text/xml")
        response = parse(data)

        test_mode = test?
        Response.new(success?(response), message_from(response), response,
          :test => test_mode,
          :authorization => response[:transactionid],
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code_response_code]
        )
      end

      def build_request(request, money)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag!("TRANSACTION", XML_ATTRIBUTES) do
          xml.tag! 'AMOUNT', amount(money)
          xml << request
        end

        xml.target!
      end

      def build_sale_or_authorization_request(creditcard, options, action)
        xml = Builder::XmlMarkup.new

        add_credit_card(xml, creditcard)
        xml.tag! 'CODE', TRANSACTIONS[action]
        add_customer_data(xml, options)
        add_address(xml, creditcard, options)
        xml.tag! 'DCI', 0 # No duplicate checking will be done, except for ORDERID
        xml.tag! 'INSTALLMENT_SEQUENCENUM', 1
        add_invoice(xml, options)
        add_merchant_key(xml, options)
        xml.tag! 'METHOD', 'CC'
        xml.tag! 'ORDERID', options[:order_id]#'30'.to_i.to_s#'22'# @options[:order_id]
        xml.tag! 'OVERRIDE_FROM', 0 # Docs say not required, but doesn't work without it
        xml.tag! 'RETAIL_LANENUM', '0' # Docs say string, but it's an integer!?
        xml.tag! 'TEST', 'TRUE'
        xml.tag! 'TOTAL_INSTALLMENTCOUNT', 0
        xml.tag! 'TRANSACTION_SERVICE', 0

        xml.target!
      end

      def build_capture_or_credit_request(identification, options)
        xml = Builder::XmlMarkup.new

        add_identification(xml, identification)
        add_customer_data(xml, options)

        xml.target!
      end

      def build_capture_request(authorization, creditcard, options, action)
        xml = Builder::XmlMarkup.new

        add_credit_card(xml, creditcard)
        xml.tag! 'CODE', TRANSACTIONS[action]
        add_customer_data(xml, options)
        xml.tag! 'DCI', 0 # No duplicate checking will be done, except for ORDERID
        xml.tag! 'INSTALLMENT_SEQUENCENUM', 1
        add_merchant_key(xml, options)
        xml.tag! 'METHOD', 'CC'
        xml.tag! 'ORDERID', options[:order_id]#'30'.to_i.to_s#'22'# @options[:order_id]
        xml.tag! 'OVERRIDE_FROM', 0 # Docs say not required, but doesn't work without it
        xml.tag! 'REF_TRANSID', authorization
        xml.tag! 'RETAIL_LANENUM', '0' # Docs say string, but it's an integer!?
        xml.tag! 'TEST', 'TRUE'
        xml.tag! 'TOTAL_INSTALLMENTCOUNT', 0
        xml.tag! 'TRANSACTION_SERVICE', 0

        xml.target!
      end

      def build_credit_request(authorization, creditcard, options, action)
#        requires!(options, :card_number)
        xml = Builder::XmlMarkup.new

        add_credit_card(xml, creditcard)
        xml.tag! 'CODE', TRANSACTIONS[action]
        add_customer_data(xml, options)
        xml.tag! 'DCI', 0 # No duplicate checking will be done, except for ORDERID
        xml.tag! 'INSTALLMENT_SEQUENCENUM', 1
        add_merchant_key(xml, options)
        xml.tag! 'METHOD', 'CC'
        xml.tag! 'ORDERID', options[:order_id]#'30'.to_i.to_s#'22'# @options[:order_id]
        xml.tag! 'OVERRIDE_FROM', 0 # Docs say not required, but doesn't work without it
        xml.tag! 'REF_TRANSID', authorization
        xml.tag! 'RETAIL_LANENUM', '0' # Docs say string, but it's an integer!?
        xml.tag! 'TEST', 'TRUE'
        xml.tag! 'TOTAL_INSTALLMENTCOUNT', 0
        xml.tag! 'TRANSACTION_SERVICE', 0

        xml.target!
      end

      def build_void_request(authorization, creditcard, options, action)
        xml = Builder::XmlMarkup.new

        add_credit_card(xml, creditcard)
        xml.tag! 'CODE', TRANSACTIONS[action]
        add_customer_data(xml, options)
        xml.tag! 'DCI', 0 # No duplicate checking will be done, except for ORDERID
        xml.tag! 'INSTALLMENT_SEQUENCENUM', 1
        add_merchant_key(xml, options)
        xml.tag! 'METHOD', 'CC'
        xml.tag! 'ORDERID', options[:order_id]#'30'.to_i.to_s#'22'# @options[:order_id]
        xml.tag! 'OVERRIDE_FROM', 0 # Docs say not required, but doesn't work without it
        xml.tag! 'REF_TRANSID', authorization
        xml.tag! 'RETAIL_LANENUM', '0' # Docs say string, but it's an integer!?
        xml.tag! 'TEST', 'TRUE'
        xml.tag! 'TOTAL_INSTALLMENTCOUNT', 0
        xml.tag! 'TRANSACTION_SERVICE', 0

        xml.target!
      end

      #########################################################################
      # FUNCTIONS RELATED TO BUILDING THE XML
      #########################################################################
      def add_credit_card(xml, creditcard)
        xml.tag!("CARD") do
          xml.tag! 'CARDCODE', creditcard.verification_value if creditcard.verification_value?
          xml.tag! 'CARDNUMBER', creditcard.number
          xml.tag! 'EXPDATE', expdate(creditcard)
        end
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def add_customer_data(xml, options)
        if options.has_key? :customer
          xml.tag! 'CUSTOMERID', options[:customer]
        end

        if options.has_key? :ip
          xml.tag! 'CUSTOMERIP', options[:ip]
        end
      end

      def add_address(xml, creditcard, options)

        if address = options[:billing_address] || options[:address]
          xml.tag!("CUSTOMER_BILL") do
            xml.tag! 'ADDRESS', address[:address1].to_s
            xml.tag! 'CITY', address[:city].to_s
            xml.tag! 'COMPANY', address[:company].to_s
            xml.tag! 'COUNTRY', address[:country].to_s
            if options.has_key? :email
              xml.tag! 'EMAIL', options[:email]
#              xml.tag! 'EMAIL', 'myemail@yahoo.com'
              xml.tag! 'EMAILRECEIPT', 'FALSE'
            end
            xml.tag! 'FIRSTNAME', creditcard.first_name
            xml.tag! 'LASTNAME', creditcard.last_name
            xml.tag! 'PHONE', address[:phone].to_s
            xml.tag! 'STATE', address[:state].blank?  ? 'n/a' : address[:state]
            xml.tag! 'ZIP', address[:zip].to_s
          end
        end

        if address = options[:shipping_address]
          xml.tag!("CUSTOMER_SHIP") do
            xml.tag! 'ADDRESS', address[:address1].to_s
            xml.tag! 'CITY', address[:city].to_s
            xml.tag! 'COMPANY', address[:company].to_s
            xml.tag! 'COUNTRY', address[:country].to_s
            xml.tag! 'FIRSTNAME', address[:first_name].to_s
            xml.tag! 'LASTNAME', address[:last_name].to_s
            xml.tag! 'STATE', address[:state].blank?  ? 'n/a' : address[:state]
            xml.tag! 'ZIP', address[:zip].to_s
          end
        else
          xml.tag!('CUSTOMER_SHIP', NIL_ATTRIBUTE) do
          end
        end

      end

      def add_invoice(xml, options)
        xml.tag! 'INVOICEDESC', options[:description]
        xml.tag! 'INVOICENUM', 'inv-8'
      end

      def add_merchant_key(xml, options)
        xml.tag!("MERCHANT_KEY") do
          xml.tag! 'GROUPID', 0
          xml.tag! 'SECUREKEY', @options[:password]
          xml.tag! 'SECURENETID', @options[:login]
        end
      end

      #########################################################################
      # FUNCTIONS RELATED TO THE RESPONSE
      #########################################################################
      def success?(response)
        response[:response_code].to_i == APPROVED
      end

      def message_from(response)
        if response[:response_code].to_i == DECLINED
          return CVVResult.messages[ response[:card_code_response_code] ] if CARD_CODE_ERRORS.include?(response[:card_code_response_code])
          return AVSResult.messages[ response[:avs_result_code] ] if AVS_ERRORS.include?(response[:avs_result_code])
        end

        return response[:response_reason_text].nil? ? '' : response[:response_reason_text][0..-1]
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)
        root = REXML::XPath.first(xml, "//GATEWAYRESPONSE")# ||
#        root = REXML::XPath.first(xml, "//ProcessTransactionResponse")# ||
#               REXML::XPath.first(xml, "//ErrorResponse")
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


    end
  end
end

