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
      API_VERSION = "4.6"
      
      POST_HEADERS = {
        "MIME-Version" => "1.0",
        "Content-Type" => "Application/PTI46",
        "Content-transfer-encoding" => "text",
        "Request-number" => '1',
        "Document-type" => "Request",
        "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }
      
      SUCCESS, APPROVED = '0', '00'
      
      class_attribute :primary_test_url, :secondary_test_url, :primary_live_url, :secondary_live_url
      
      self.primary_test_url = "https://orbitalvar1.paymentech.net/authorize"
      self.secondary_test_url = "https://orbitalvar2.paymentech.net/authorize"
      
      self.primary_live_url = "https://orbital1.paymentech.net/authorize"
      self.secondary_live_url = "https://orbital2.paymentech.net/authorize"
      
      self.supported_countries = ["US", "CA"]
      self.default_currency = "CAD"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      
      self.display_name = 'Orbital Paymentech'
      self.homepage_url = 'http://chasepaymentech.com/'
      
      self.money_format = :cents
            
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

      AVS_SUPPORTED_COUNTRIES = ['US', 'CA', 'UK', 'GB']

      def initialize(options = {})
        requires!(options, :merchant_id)
        requires!(options, :login, :password) unless options[:ip_authentication]
        @options = options
        super
      end
      
      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml('A', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency])        
          add_address(xml, creditcard, options)   
        end
        commit(order)
      end
      
      # AC – Authorization and Capture
      def purchase(money, creditcard, options = {})
        order = build_new_order_xml('AC', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency])
          add_address(xml, creditcard, options)   
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
        end
        commit(order)
      end

      def credit(money, authorization, options= {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end
      
      # setting money to nil will perform a full void
      def void(authorization, options = {})
        order = build_void_request_xml(authorization, options)
        commit(order)
      end
    
      private                       
            
      def add_customer_data(xml, options)
        if options[:customer_ref_num]
          xml.tag! :CustomerProfileFromOrderInd, 'S'
          xml.tag! :CustomerRefNum, options[:customer_ref_num]
        else
          xml.tag! :CustomerProfileFromOrderInd, 'A'
        end
      end
      
      def add_soft_descriptors(xml, soft_desc)
        xml.tag! :SDMerchantName, soft_desc.merchant_name
        xml.tag! :SDProductDescription, soft_desc.product_description
        xml.tag! :SDMerchantCity, soft_desc.merchant_city
        xml.tag! :SDMerchantPhone, soft_desc.merchant_phone
        xml.tag! :SDMerchantURL, soft_desc.merchant_url
        xml.tag! :SDMerchantEmail, soft_desc.merchant_email
      end

      def add_address(xml, creditcard, options)      
        if address = options[:billing_address] || options[:address]
          add_avs_details(xml, address)
          xml.tag! :AVSname, creditcard.name
          xml.tag! :AVScountryCode, address[:country]
        end
      end

      def add_creditcard(xml, creditcard, currency=nil)
        xml.tag! :AccountNum, creditcard.number
        xml.tag! :Exp, expiry_date(creditcard)
        
        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
        
        xml.tag! :CardSecValInd, 1 if creditcard.verification_value? && %w( visa discover ).include?(creditcard.brand)
        xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
      end
      
      def add_refund(xml, currency=nil)
        xml.tag! :AccountNum, nil
        
        xml.tag! :CurrencyCode, currency_code(currency)
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
      end
      
      def add_avs_details(xml, address)
        return unless AVS_SUPPORTED_COUNTRIES.include?(address[:country].to_s)

        xml.tag! :AVSzip, address[:zip]
        xml.tag! :AVSaddress1, address[:address1]
        xml.tag! :AVSaddress2, address[:address2]
        xml.tag! :AVScity, address[:city]
        xml.tag! :AVSstate, address[:state]
        xml.tag! :AVSphoneNum, address[:phone] ? address[:phone].scan(/\d/).join.to_s : nil
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
          {:authorization => "#{response[:tx_ref_num]};#{response[:order_id]}",
           :test => self.test?,
           :avs_result => {:code => response[:avs_resp_code]},
           :cvv_result => response[:cvv2_resp_code]
          }
        )
      end
      
      def remote_url
        unless $!.class == ActiveMerchant::ConnectionError
          self.test? ? self.primary_test_url : self.primary_live_url
        else
          self.test? ? self.secondary_test_url : self.secondary_live_url
        end
      end

      def success?(response)
        if response[:message_type].nil? || response[:message_type] == "R"
          response[:proc_status] == SUCCESS
        else
          response[:proc_status] == SUCCESS &&
            response[:resp_code] == APPROVED
        end
      end
      
      def message_from(response)
        success?(response) ? 'APPROVED' : response[:resp_msg] || response[:status_msg]
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
            
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]
            xml.tag! :OrderID, format_order_id(parameters[:order_id])
            xml.tag! :Amount, amount(money)
            
            # Append Transaction Reference Number at the end for Refund transactions
            if action == "R"
              tx_ref_num, _ = parameters[:authorization].split(';')
              xml.tag! :TxRefNum, tx_ref_num
            end
          end
        end
        xml.target!
      end
      
      def build_mark_for_capture_xml(money, authorization, parameters = {})
        tx_ref_num, order_id = authorization.split(';')
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :MarkForCapture do
            add_xml_credentials(xml)
            xml.tag! :OrderID, order_id
            xml.tag! :Amount, amount(money)
            add_bin_merchant_and_terminal(xml, parameters)
            xml.tag! :TxRefNum, tx_ref_num
          end
        end
        xml.target!
      end
      
      def build_void_request_xml(authorization, parameters = {})
        tx_ref_num, order_id = authorization.split(';')
        xml = xml_envelope
        xml.tag! :Request do
          xml.tag! :Reversal do
            add_xml_credentials(xml)
            xml.tag! :TxRefNum, tx_ref_num
            xml.tag! :TxRefIdx, parameters[:transaction_index]
            xml.tag! :OrderID, order_id
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
    end
  end
end
