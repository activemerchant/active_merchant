require 'rexml/document'

module ActiveMerchant
  module Billing
    
    # In NZ DPS supports ANZ, Westpac, National Bank, ASB and BNZ. 
    # In Australia DPS supports ANZ, NAB, Westpac, CBA, St George and Bank of South Australia. 
    # The Maybank in Malaysia is supported and the Citibank for Singapore.
    class PaymentExpressGateway < Gateway
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      class_inheritable_accessor :default_currency
      self.default_currency = 'NZD'

      PAYMENT_URL = 'https://www.paymentexpress.com/pxpost.aspx'
      
      APPROVED = '1'
      
      TRANSACTIONS = {
        :purchase => 'Purchase',
        :credit => 'Refund',
        :authorization => 'Auth',
        :capture => 'Complete'
      }

      # We require the DPS gateway username and password when the object is created.
      def initialize(options = {})
        # A DPS username and password must exist 
        requires!(options, :login, :password)
        # Make the options an instance variable
        @options = options
        super
      end

      # PS supports all major credit cards; Visa, Mastercard, Amex, Diners, BankCard & JCB. 
      # Various white label cards can be accepted as well; Farmers, AirNZCard and Elders etc. 
      # Please note that not all acquirers and Eftpos networks can support some of these card types.
      # VISA, Mastercard, Diners Club and Farmers cards are supported
      #
      # However, regular accounts with DPS only support VISA and Mastercard
      def self.supported_cardtypes
        [ :visa, :master, :american_express, :diners_club, :jcb ]
      end
      
      # Funds are transferred immediately.
      def purchase(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
        
        request = build_purchase_or_authorization_request(money, credit_card, options)
        commit(:purchase, request)      
      end
      
      # NOTE: Perhaps in options we allow a transaction note to be inserted
      # Verifies that funds are available for the requested card and amount and reserves the specified amount.
      # See: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#Authcomplete
      def authorize(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
        
        request = build_purchase_or_authorization_request(money, credit_card, options)
        commit(:authorization, request)
      end
      
      # Transfer pre-authorized funds immediately
      # See: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#Authcomplete
      def capture(money, identification, options = {})
        request = build_capture_or_credit_request(money, identification, options)                                            
        commit(:capture, request)
      end
      
      # Refund funds to the card holder
      def credit(money, identification, options = {})
        requires!(options, :description)
        
        request = build_capture_or_credit_request(money, identification, options)                                            
        commit(:credit, request)
      end

      private
      
      def build_purchase_or_authorization_request(money, credit_card, options)
        result = new_transaction
      
        add_credit_card(result, credit_card)
        add_amount(result, money)
        add_invoice(result, options)
        add_address_verification_data(result, options)
        
        result
      end
      
      def build_capture_or_credit_request(money, identification, options)
        result = new_transaction
      
        add_amount(result, money)
        add_invoice(result, options)
        add_reference(result, identification)
        
        result
      end
      
      def add_credentials(xml)
        xml.add_element("PostUsername").text = @options[:login]
        xml.add_element("PostPassword").text = @options[:password]
      end
      
      def add_reference(xml, identification)
        xml.add_element("DpsTxnRef").text = identification
      end
      
      def add_credit_card(xml, credit_card)
        xml.add_element("CardHolderName").text = credit_card.name
        xml.add_element("CardNumber").text = credit_card.number
        xml.add_element("DateExpiry").text = format_date(credit_card.month, credit_card.year)
        
        if credit_card.verification_value?
          xml.add_element("Cvc2").text = credit_card.verification_value
        end
        
        if requires_start_date_or_issue_number?(credit_card)
          xml.add_element("DateStart").text = format_date(credit_card.start_month, credit_card.start_year) unless credit_card.start_month.blank? || credit_card.start_year.blank?
          xml.add_element("IssueNumber").text = credit_card.issue_number unless credit_card.issue_number.blank?
        end
      end
      
      def add_amount(xml, money)
        xml.add_element("Amount").text = amount(money)
        xml.add_element("InputCurrency").text = currency(money)
      end
      
      def add_transaction_type(xml, action)
        xml.add_element("TxnType").text = TRANSACTIONS[action]
      end
      
      def add_invoice(xml, options)
        xml.add_element("TxnId").text = options[:order_id] unless options[:order_id].blank?
        xml.add_element("MerchantReference").text = options[:description] unless options[:description].blank?
      end
      
      def add_address_verification_data(xml, options)
        address = options[:billing_address] || options[:address]
        return if address.nil?
        
        xml.add_element("EnableAvsData").text = 0
        xml.add_element("AvsAction").text = 0
        
        xml.add_element("AvsStreetAddress").text = address[:address1]
        xml.add_element("AvsPostCode").text = address[:zip]
      end
      
      def new_transaction
        REXML::Document.new.add_element("Txn")
      end

      # Take in the request and post it to DPS
      def commit(action, request)
        add_credentials(request)
        add_transaction_type(request, action)
        
        # Next, post it to the server
        response = ssl_post(PAYMENT_URL, request.to_s)

        # Parse the XML response
        @response = parse_response(response)
        
        success = @response[:success] == APPROVED
        test = @response[:test_mode] == '1'
        
        # Return a response
        Response.new(success, @response[:response_text], @response,
          :test => test,
          :authorization => @response[:dps_txn_ref]
        )
      end

      # Response XML documentation: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#XMLTxnOutput
      def parse_response(xml_string)
        response = {}

        xml = REXML::Document.new(xml_string)          

        # Gather all root elements such as HelpText
        xml.elements.each('Txn/*') do |element|
          response[element.name.underscore.to_sym] = element.text
        end

        # Gather all transaction elements and prefix with "account_"
        # So we could access the MerchantResponseText by going
        # response[account_merchant_response_text]
        xml.elements.each('Txn/Transaction/*') do |element|
          response[element.name.underscore.to_sym] = element.text
        end

        response
      end
      
      def format_date(month, year)
        "#{format(month, :two_digits)}#{format(year, :two_digits)}"
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
    end
  end
end