# Portions of the Cardstream gateway by Jonah Fox and Thomas Nichols

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    #
    # CardStream supports the following credit cards, which are auto-detected by
    # the gateway based on the card number used: 
    # * AM American Express 
    # * Diners Club 
    # * Electron 
    # * JCB 
    # * UK Maestro 
    # * Maestro International 
    # * Mastercard 
    # * Solo 
    # * Style 
    # * Switch 
    # * Visa Credit 
    # * Visa Debit 
    # * Visa Purchasing 
    #
    class CardStreamGateway < Gateway
      TEST_URL = 'https://www.cardstream.com/merchantsecure/Cardstream/VPDirect.cfm'
      LIVE_URL = 'https://www.cardstream.com/merchantsecure/Cardstream/VPDirect.cfm'
      
      self.money_format = :cents
      self.default_currency = 'GBP'
      self.supported_countries = ['GB']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :solo, :switch]
      self.homepage_url = 'http://www.cardstream.com/'
      self.display_name = 'CardStream'

      APPROVED = '00'

      CURRENCY_CODES = { 
        "AUD"=> '036',
        "CAD"=> '124',
        "CZK"=> '203',
        "DKK"=> '208',
        "HKD"=> '344',
        "ICK"=> '352',
        "JPY"=> '392',
        "NOK"=> '578',
        "SGD"=> '702',
        "SEK"=> '752',
        "CHF"=> '756',
        "GBP"=> '826',
        "USD"=> '840',
        "EUR"=> '978'
      }
      
      TRANSACTIONS = {
        :purchase => 'ESALE_KEYED',
        :refund => 'EREFUND_KEYED',
        :authorization => 'ESALE_KEYED'
      }
      
      POST_HEADERS = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      attr_reader :url
      attr_reader :response
      attr_reader :options

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)
        
        post = {}
        
        add_amount(post, money, options)
        add_invoice(post, money, credit_card, options)
        add_credit_card(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)

        commit(:purchase, post)
      end
  
      private
      
      def add_amount(post, money, options)
        add_pair(post, :Amount, amount(money), :required => true)
        add_pair(post, :CurrencyCode, currency_code(options[:currency] || currency(money)), :required => true)
      end

      def add_customer_data(post, options)
        add_pair(post, :BillingEmail, options[:email])
        add_pair(post, :BillingPhoneNumber, options[:phone])
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        
        return if address.nil?

        add_pair(post, :BillingStreet, address[:address1])
        add_pair(post, :BillingHouseNumber, address[:address2])
        add_pair(post, :BillingCity, address[:city])
        add_pair(post, :BillingState, address[:state])
        add_pair(post, :BillingPostCode, address[:zip])
      end

      def add_invoice(post, money, credit_card, options)
        add_pair(post, :TransactionUnique, options[:order_id], :required => true)
        add_pair(post, :OrderDesc, options[:description] || options[:order_id], :required => true)
        
        if [ 'american_express', 'diners_club' ].include?(credit_card.type.to_s)
          add_pair(post, :AEIT1Quantity,  1) 
          add_pair(post, :AEIT1Description,  options[:description] || options[:order_id]) 
          add_pair(post, :AEIT1GrossValue, amount(money))
        end
      end

      def add_credit_card(post, credit_card)
        add_pair(post, :CardName, credit_card.name, :required => true)
        add_pair(post, :CardNumber, credit_card.number, :required => true)
         
        add_pair(post, :ExpiryDateMM, format(credit_card.month, :two_digits), :required => true)
        add_pair(post, :ExpiryDateYY, format(credit_card.year, :two_digits), :required => true)
         
        if requires_start_date_or_issue_number?(credit_card)
          add_pair(post, :StartDateMM, format(credit_card.start_month, :two_digits))
          add_pair(post, :StartDateYY, format(credit_card.start_year, :two_digits))
          
          add_pair(post, :IssueNumber, format_issue_number(credit_card))
        end
        
        add_pair(post, :CV2, credit_card.verification_value)
      end
      
      def format_issue_number(credit_card)
        credit_card.type.to_s == 'solo' ? format(credit_card.issue_number, :two_digits) : credit_card.issue_number
      end

      def commit(action, parameters)
        data = ssl_post(test? ? TEST_URL : LIVE_URL, post_data(action, parameters), POST_HEADERS)
        @response = parse(data)

        success = @response[:response_code] == APPROVED
        message = message_from(@response)

        Response.new(success, message, @response,
          :test => test?,
          :authorization => @response[:cross_reference]
        )
      end

      def message_from(results)
        results[:response_code] == APPROVED ? "APPROVED" : results[:message]
      end

      def post_data(action, parameters = {})
        parameters.update(
          :MerchantPassword => @options[:password],
          :MerchantID => @options[:login],
          :MessageType => TRANSACTIONS[action],
          :CallBack => "disable",
          :DuplicateDelay => "0",
          :EchoCardType => "YES",
          :EchoAmount => "YES",
          :EchoAVSCV2ResponseCode => "YES",
          :ReturnAVSCV2Message => "YES",
          :CountryCode => '826' # 826 for UK based merchant
        )
        
        add_pair(parameters, :Dispatch, action == :authorization ? "LATER" : "NOW")
    
        parameters.collect { |key, value| "VP#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
      
      # VPCrossReference 
      # The value in VPCrossReference on a success transaction will contain 
      # a unique reference that you may use to run future transactions. 
      # Please note that cross reference transactions must come a static IP 
      # addressed that has been pre-registered with Cardstream. To 
      # register an IP address please send it to support@cardstream.com 
      # with your Cardstream issued merchant ID and it will be added to 
      # your account.
      def parse(body)
        result = {}
        pairs = body.split("&")
        pairs.each do |pair|
          a = pair.split("=")
          result[a[0].gsub(/^VP/,'').underscore.to_sym] = a[1]
        end
        
        result
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      def currency_code(currency)
        CURRENCY_CODES[currency]
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end
    end
  end
end

