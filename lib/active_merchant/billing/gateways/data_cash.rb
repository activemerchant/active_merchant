# Author::    MoneySpyder, http://moneyspyder.co.uk

module ActiveMerchant
  module Billing
    class DataCashGateway < Gateway
      self.default_currency = 'GBP'
      self.supported_countries = ['GB']
      
      # From the DataCash docs; Page 13, the following cards are
      # usable:
      # American Express, ATM, Carte Blanche, Diners Club, Discover,
      # EnRoute, GE Capital, JCB, Laser, Maestro, Mastercard, Solo,
      # Switch, Visa, Visa Delta, VISA Electron, Visa Purchasing  
      self.supported_cardtypes = [ :visa, :master, :american_express, :discover, :diners_club, :jcb, 
          :maestro, :switch, :solo, :laser ]
          
      self.homepage_url = 'http://www.datacash.com/'
      self.display_name = 'DataCash'
      
      # Datacash server URLs
      TEST_URL = 'https://testserver.datacash.com/Transaction'
      LIVE_URL = 'https://mars.transaction.datacash.com/Transaction'
      
      # Different Card Transaction Types
      AUTH_TYPE = 'auth'
      CANCEL_TYPE = 'cancel'
      FULFILL_TYPE = 'fulfill'
      PRE_TYPE = 'pre'
      
      # Constant strings for use in the ExtendedPolicy complex element for
      # CV2 checks
      POLICY_ACCEPT = 'accept'
      POLICY_REJECT = 'reject'
      
      # Datacash success code
      DATACASH_SUCCESS = '1'
      
      # Class attributes
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      # Creates a new DataCashGateway
      # 
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> -- The Datacash account login.
      # * <tt>:password</tt> -- The Datacash account password.
      # * <tt>:test => +true+ or +false+</tt> -- Use the test or live Datacash url.
      #     
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased.  Either an Integer value in cents or a Money object.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
      
        request = build_purchase_or_authorization_request(AUTH_TYPE, money, credit_card, options)
      
        commit(request)
      end
      
      # Performs an authorization, which reserves the funds on the customer's credit card, but does not 
      # charge the card.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized.  Either an Integer value in cents or a Money object.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.   
      def authorize(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
        
        request = build_purchase_or_authorization_request(PRE_TYPE, money, credit_card, options)
        
        commit(request)
      end
      
      # Captures the funds from an authorized transaction.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.   
      def capture(money, authorization, options = {})
        request = build_void_or_capture_request(FULFILL_TYPE, money, authorization, options)

        commit(request)
      end                    
      
      # Void a previous transaction
      # 
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.   
      def void(authorization, options = {})
        request = build_void_or_capture_request(CANCEL_TYPE, nil, authorization, options)
        
        commit(request)
      end
      
      # Is the gateway running in test mode?
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
    
      private                         
      # Create the xml document for a 'cancel' or 'fulfill' transaction.
      # 
      # Final XML should look like:
      # <Request>
      #  <Authentication>
      #    <client>99000001</client>
      #    <password>******</password>
      #  </Authentication>
      #  <Transaction>
      #    <TxnDetails>
      #      <amount>25.00</amount>
      #    </TxnDetails>
      #    <HistoricTxn>
      #      <reference>4900200000000001</reference>
      #      <authcode>A6</authcode>
      #      <method>fulfill</method>
      #    </HistoricTxn>
      #  </Transaction>
      # </Request>
      # 
      # Parameters:
      #   -type must be FULFILL_TYPE or CANCEL_TYPE
      #   -money - optional - A money object with the price and currency
      #   -authorization - the Datacash reference number from a previous
      #                    succesful authorize transaction
      #   -authcode - the Datacash authcode
      #   -order_id - The merchants reference
      #   
      # Returns:
      #   -Builder xml document
      #
      def build_void_or_capture_request(type, money, authorization, options)
        reference, auth_code = authorization.to_s.split(';')
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          
          xml.tag! :Transaction do
            xml.tag! :HistoricTxn do
              xml.tag! :reference, reference
              xml.tag! :authcode, auth_code
              xml.tag! :method, type
            end
            
            if money
              xml.tag! :TxnDetails do
                xml.tag! :merchantreference, format_reference_number(options[:order_id])
                xml.tag! :amount, amount(money), :currency => options[:currency] || currency(money)
              end
            end
          end
        end
        xml.target!
      end
      
      # Create the xml document for an 'auth' or 'pre' transaction.
      # 
      # Final XML should look like:
      # 
      # <Request>
      #  <Authentication>
      #    <client>99000000</client>
      #    <password>*******</password>
      #  </Authentication>
      #  <Transaction>
      #    <TxnDetails>
      #      <merchantreference>123456</merchantreference>
      #      <amount currency="EUR">10.00</amount>
      #    </TxnDetails>
      #    <CardTxn>
      #      <Card>
      #        <pan>4444********1111</pan>
      #        <expirydate>03/04</expirydate>
      #        <Cv2Avs>
      #          <street_address1>Flat 7</street_address1>
      #          <street_address2>89 Jumble
      #               Street</street_address2>
      #          <street_address3>Mytown</street_address3>
      #          <postcode>AV12FR</postcode>
      #          <cv2>123</cv2>
      #           <ExtendedPolicy>
      #             <cv2_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="reject"/>
      #             <postcode_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="accept"/>
      #             <address_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="accept"/>
      #           </ExtendedPolicy>
      #        </Cv2Avs>
      #      </Card>
      #      <method>auth, </method>
      #    </CardTxn>
      #  </Transaction>
      # </Request>
      # 
      # Parameters:
      #   -type must be 'auth' or 'pre'
      #   -money - A money object with the price and currency
      #   -credit_card - The credit_card details to use
      #   -options:
      #     :order_id is the merchant reference number
      #     :billing_address is the billing address for the cc
      #     :address is the delivery address
      #   
      # Returns:
      #   -xml: Builder document containing the markup
      #
      def build_purchase_or_authorization_request(type, money, credit_card, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          
          xml.tag! :Transaction do
            xml.tag! :CardTxn do
              xml.tag! :method, type
              
              add_credit_card(xml, credit_card, options[:billing_address] || options[:address])
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money), :currency => options[:currency] || currency(money)
            end
          end
        end
        xml.target!
      end
      
      # Adds the authentication element to the passed builder xml doc
      # 
      # Parameters:
      #   -xml: Builder document that is being built up
      #   
      # Returns:
      #   -none: The results is stored in the passed xml document
      #   
      def add_authentication(xml)
        xml.tag! :Authentication do
          xml.tag! :client, @options[:login]
          xml.tag! :password, @options[:password]
        end
      end
      
      # Add credit_card detals to the passed XML Builder doc
      # 
      # Parameters:
      #   -xml: Builder document that is being built up
      #   -credit_card: ActiveMerchant::Billing::CreditCard object
      #   -billing_address: Hash containing all of the billing address details
      #   
      # Returns:
      #   -none: The results is stored in the passed xml document
      #   
      def add_credit_card(xml, credit_card, address)
        xml.tag! :Card do
          
          # DataCash calls the CC number 'pan'
          xml.tag! :pan, credit_card.number
          xml.tag! :expirydate, format_date(credit_card.month, credit_card.year)
          
          # optional values - for Solo etc
          if [ 'switch', 'solo' ].include?(credit_card.type.to_s)
            
            xml.tag! :issuenumber, credit_card.issue_number unless credit_card.issue_number.blank?
            
            if !credit_card.start_month.blank? && !credit_card.start_year.blank?
              xml.tag! :startdate, format_date(credit_card.start_month, credit_card.start_year)
            end
          end
            
          xml.tag! :Cv2Avs do
            xml.tag! :cv2, credit_card.verification_value if credit_card.verification_value?
            xml.tag! :street_address1, address[:address1] unless address[:address1].blank?
            xml.tag! :street_address2, address[:address2] unless address[:address2].blank?
            xml.tag! :street_address3, address[:address3] unless address[:address3].blank?
            xml.tag! :street_address4, address[:address4] unless address[:address4].blank?
            xml.tag! :postcode, address[:zip] unless address[:zip].blank?
            
            # The ExtendedPolicy defines what to do when the passed data 
            # matches, or not...
            # 
            # All of the following elements MUST be present for the
            # xml to be valid (or can drop the ExtendedPolicy and use
            # a predefined one
            xml.tag! :ExtendedPolicy do
              xml.tag! :cv2_policy, 
              :notprovided =>   POLICY_REJECT,
              :notchecked =>    POLICY_REJECT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_REJECT
              xml.tag! :postcode_policy,
              :notprovided =>   POLICY_ACCEPT,
              :notchecked =>    POLICY_ACCEPT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_ACCEPT
              xml.tag! :address_policy, 
              :notprovided =>   POLICY_ACCEPT,
              :notchecked =>    POLICY_ACCEPT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_ACCEPT
            end
          end
        end
      end
      
      # Send the passed data to DataCash for processing
      # 
      # Parameters:
      #   -request: The XML data that is to be sent to Datacash
      #   
      # Returns:
      #   - ActiveMerchant::Billing::Response object
      #   
      def commit(request)
        url = test? ? TEST_URL : LIVE_URL
  
        @response = parse(ssl_post(url, request))      
        success = @response[:status] == DATACASH_SUCCESS
        message = @response[:reason]
        
        Response.new(success, message, @response,
                     :test => test?,
                     :authorization => "#{@response[:datacash_reference]};#{@response[:authcode]}"
        )
      end
      
      # Returns a date string in the format Datacash expects
      # 
      # Parameters:
      #   -month: integer, the month
      #   -year: integer, the year
      # 
      # Returns:
      #   -String: date in MM/YY format
      #
      def format_date(month, year)
        "#{format(month,:two_digits)}/#{format(year, :two_digits)}"
      end
      
      # Parse the datacash response and create a Response object
      #
      # Parameters:
      #   -body: The XML returned from Datacash
      # 
      # Returns:
      #   -a hash with all of the values returned in the Datacash XML response
      # 
      def parse(body)
        
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//Response")
        
        root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        
        response
      end     
      
      # Parse an xml element
      #
      # Parameters:
      #   -response: The hash that the values are being returned in
      #   -node: The node that is currently being read
      # 
      # Returns:
      # -  none (results are stored in the passed hash)
      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
      
      def format_reference_number(number)
        number.to_s.gsub(/[^A-Za-z0-9]/, '').rjust(6, "0")
      end
    end
  end
end
