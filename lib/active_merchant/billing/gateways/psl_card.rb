# Author::    MoneySpyder, http://moneyspyder.co.uk

module ActiveMerchant
  module Billing
    #
    # ActiveMerchant PSL Card Gateway
    # 
    # Notes:
    #   -To be able to use the capture function, the IP address of the machine must be
    #    registered with PSL
    #   -ESALE_KEYED should only be used in situations where the cardholder perceives the 
    #    transaction to be Internet-based, such as purchasing from a web site/on-line store.  
    #    If the Internet is used purely for the transport of information from the merchant 
    #    directly to the gateway then the appropriate cardholder present or not present message 
    #    type should be used rather than the ‘E’ equivalent.
    #   -The CV2 / AVS policies are set up with the account settings when signing up for an account
    #   
    #
    class PslCardGateway < Gateway
      
      # PslCard server URL - The url is the same whether testing or live - use
      # the test account when testing...
      URL = 'https://pslcard3.paymentsolutionsltd.com/secure/transact.asp?'
      
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      # eCommerce sale transaction, details keyed by merchant or cardholder
      MESSAGE_TYPE = 'ESALE_KEYED' 
      
      # The type of response that we want to get from PSL, options are HTML, XML or REDIRECT
      RESPONSE_ACTION = 'HTML'
      
      # Currency Codes
      CURRENCY_CODES = {
        'AUD' => 036,
        'GBP' => 826,
        'USD' => 840
      }
      
      #The terminal used - only for swipe transactions, so hard coded to 32 for online
      EMV_TERMINAL_TYPE = 32

      # Default ISO 3166 country code (GB)
      DEFAULT_COUNTRY_CODE = 826
      
      #Different Dispatch types
      DISPATCH_LATER  = 'LATER'
      DISPATCH_NOW    = 'NOW'
      
      # Return codes
      APPROVED = '00'
      
      #Nominal amount to authorize for a 'dispatch later' type
      #The nominal amount is held straight away, when the goods are ready
      #to be dispatched, PSL is informed and the full amount is the
      #taken.
      NOMINAL_AMOUNT = Money.new(101, 'GBP')
      
      # Create a new PslCardGateway
      # 
      # The gateway requires that a valid :login be passed in the options hash
      # 
      # Paramaters:
      #   -options:
      #     :login -    the PslCard account login (required)
      #     :country -  The three digit ISO 3166 country code 
      #                 where the application is located - defaults to GB (826) (optional)
      #     :test -     boolean, - not really needed as the it is determined by the passed account number
      #
      def initialize(options = {})
        requires!(options, :login)
        
        #check the country is provided, if not, set to default
        if options[:country].nil?
          options.update(:country => DEFAULT_COUNTRY_CODE)
        end
        
        @options = options
        super
      end
      
      # Authorize the transaction
      # 
      # Reserves the funds on the customer's credit card, but does not 
      # charge the card.
      #
      # This implementation does not authorize the full amount, rather it checks that the full amount
      # is available and only 'reserves' the nominal amount (currently a pound and a penny)
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: the PSL cross reference from the previous authorization
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #   
      def authorize(money, creditcard, options = {})
      
        billing_address = options[:billing_address] || options[:address]
        
        request = build_purchase_or_authorization_request(money, creditcard, billing_address, DISPATCH_LATER, options)
        
        commit(request)
      end
      
      # Post an authorization. 
      #
      # Captures the funds from an authorized transaction. 
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: The PSL Cross Reference
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #
      def capture(money, authorization, options = {})

        request = build_capture_request(money, authorization, options)

        commit(request)
      end

      # Purchase the item straight away
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: the PSL cross reference from the previous authorization
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #   
      def purchase(money, creditcard, options = {})
        billing_address = options[:billing_address] || options[:address]
        request = build_purchase_or_authorization_request(money, creditcard, billing_address, DISPATCH_NOW, options)
        commit(request)
      end

      # Void a previous transaction
      # 
      # Parameters:
      #   -authorization: the PSL cross reference from the previous authorization
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #   
      def void(authorization, options = {})
        
        # Applogies. Do not have the documentation to implement this at
        # the current time.
        
        raise 'Method Not Yet Implemented'
      end
      
      # Visa Credit, Visa Debit, Mastercard, Maestro, Solo, Electron,
      # American Express, Diners Club, JCB, International Maestro,
      # Style, Clydesdale Financial Services, Other
      # 
      # Parameters:
      #   -none
      # 
      # Returns:
      #   -the list of all supported cards
      #   
      def self.supported_cardtypes
        [:visa, :master, :american_express, :diners_club, :jcb, :solo]
      end
      
      # Return whether or not the gateway is in test mode
      # 
      # Parameters:
      #   -none
      # 
      # Returns:
      #   -boolean
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      ###############################
      #       Private Methods       #
      ###############################
      
      private
      
      # Create a PSL request for authorization or purcharse
      #
      # Paramaters:
      #   -money: Money object with the full amount to be charged
      #   -creditcard: ActiveMerchant::Billing::CreditCard object
      #   -billing_address: hash with all billing address information
      #   -dispatch_type: What type of transaction is being created
      #
      # Returns:
      #   -a hash with all the values to be sent to PSL
      #
      def build_purchase_or_authorization_request(money, creditcard, billing_address, dispatch_type, options = {})
        post = {}
        add_required_fields(post, money, dispatch_type)
        
        # Credit Card details
        post[:CardNumber] = creditcard.number
        post[:EMVTerminalType] = EMV_TERMINAL_TYPE
        post[:ExpMonth] = creditcard.month
        post[:ExpYear] = creditcard.year
        post[:IssueNumber] = creditcard.issue_number unless creditcard.issue_number.blank?
        post[:StartMonth] = creditcard.start_month unless creditcard.start_month.blank?
        post[:StartYear] = creditcard.start_year unless creditcard.start_year.blank?
        
        # CV2 check
        post[:AVSCV2Check] = creditcard.verification_value.blank? ? 'NO' : 'YES'
        post[:CV2] = creditcard.verification_value unless creditcard.verification_value.blank?
        
        post[:EchoAmount] = 'YES'
        
        post[:MerchantName] = 'Merchant Name' #May use this as the order_id field
        post[:SCBI] = 'YES'                   #Return information about the transaction
        
        
        address = ''
        address << billing_address[:address1] + ' ' unless billing_address[:address1].blank?
        address << billing_address[:address2] + ' ' unless billing_address[:address2].blank?
        address << billing_address[:address3] + ' ' unless billing_address[:address3].blank?
        address << billing_address[:address4] unless billing_address[:address4].blank?
        post[:QAAddress] = address
        post[:QAPostcode] = billing_address[:zip]
        post[:QAName] = creditcard.first_name + ' ' + creditcard.last_name
        
        post[:MessageType] = MESSAGE_TYPE
        
        # Additional fields
        post[:OrderID] = options[:order_id] unless options[:order_id].blank?
        post
        
        
        # Not used
        #post[:RetOKAddress] = 'SUCCESS'       #Arbitrary string - not used
        #post[:RetNotOKAddress] = 'FAIL'       #as above
      end
      
      # Create a request for a capture transaction
      # 
      # Paramaters:
      #   -money The money object with the total to be charged
      #   -authorization: the PSL reference number
      #   -options:
      #
      # Returns:
      #   -hash with all data set for PSL
      #
      def build_capture_request(money, authorization, options)
        post = {}
        add_required_fields(post, money, DISPATCH_NOW)
        
        # If type is capture
        post[:CrossReference] = authorization
        
        post
      end
      
      # Add the required fields for all transactions
      # 
      # Paramaters:
      #   -post The hash to add the values to
      #   -money The money object with the total to be charged
      #   -dispatch_type: The type of message being sent
      # Returns:
      #   -none - all data stored in the passed hash
      #
      def add_required_fields(post, money, dispatch_type)
      
        post[:CountryCode] = @options[:country]
        post[:CurrencyCode] = currency_code(money)
        
        if dispatch_type == DISPATCH_LATER
          post[:amount] = NOMINAL_AMOUNT.cents
          post[:DispatchLaterAmount] = money.cents
        else
          post[:amount] = money.cents
        end
        
        post[:Dispatch] = dispatch_type
        post[:MerchantID] = @options[:login]
        post[:ValidityID] = @options[:password]
        post[:ResponseAction] = RESPONSE_ACTION
      end
      
      # Get the currency code for the passed money object
      # 
      # The money class stores the currency as an ISO 4217:2001 Alphanumeric,
      # however PSL requires the ISO 4217:2001 Numeric code.
      # 
      # Parameters:
      #   -money: Money object with the amount and currency
      #   
      # Returns:
      #   -the ISO 4217:2001 Numberic currency code
      #   
      def currency_code(money)
        #get the stored currency from the money object
        currency = currency(money)

        #find the code value
        CURRENCY_CODES[currency].to_s
      end
      
      # Returns a date string in the format PSL expects
      # 
      # Parameters:
      #   -month: integer, the month
      #   -year: integer, the year
      # 
      # Returns:
      #   -String: date in YYMM format
      #   
      def format_date(month, year)
        "#{format(year, :two_digits)}#{format(month,:two_digits)}"
      end

      
      # Find the currency of the Money object passed
      # 
      # Parameters:
      #   -money: The money object that we are looking at
      #
      # Returns:
      #   -string: The three digit currency code (These are
      #            ISO 4217:2001 codes)
      #
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
      # Parse the PSL response and create a Response object
      #
      # Parameters:
      #   -body:  The response string returned from PSL, Formatted:
      #           Key=value&key=value...
      # 
      # Returns:
      #   -a hash with all of the values returned in the PSL response
      #
      def parse(body)

        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value)
        end
        fields.symbolize_keys
      end
      
      # Send the passed data to PSL for processing
      #
      # Parameters:
      #   -request: The data that is to be sent to PSL
      #
      # Returns:
      #   - ActiveMerchant::Billing::Response object
      #
      def commit(request)

        result = ssl_post(URL, post_data(request))
        
        @response = parse(result)
        
        success = @response[:ResponseCode] == APPROVED
        message = @response[:Message]
        
        Response.new(success, message, @response, 
            :test => test?, 
            :authorization => @response[:CrossReference]
        )
      end
      
      # Put the passed data into a format that can be submitted to PSL
      # Key=Value&Key=Value...
      #
      # Any ampersands and equal signs are removed from the data being posted
      # as PSL puts them back into the response string which then cannot be parsed. 
      # This is after escaping before sending the request to PSL - this is a work
      # around for the time being
      # 
      # Parameters:
      #   -post: Hash of all the data to be sent
      #
      # Returns:
      #   -String: the data to be sent
      #
      def post_data(post)
        post.collect { |key, value|
          "#{key}=#{CGI.escape(value.to_s.tr('&=', ' '))}"
        }.join("&")
      end
    end
  end
end
