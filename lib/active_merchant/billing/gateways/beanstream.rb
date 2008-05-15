module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This class implements the Canadian {Beanstream}[http://www.beanstream.com] payment gateway.
    # It is also named TD Canada Trust Online Mart payment gateway.
    # To learn more about the specification of Beanstream gateway, please read the OM_Direct_Interface_API.pdf,
    # which you can get from your Beanstream account or get from me by email.
    #  
    # == Supported transaction types by Beanstream:
    # * +P+ - Purchase
    # * +PA+ - Pre Authorization
    # * +PAC+ - Pre Authorization Completion
    #  
    # == Notes 
    # * Recurring billing is not yet implemented.
    # * Adding of order products information is not implemented.
    # * Ensure that country and province data is provided as a code such as "CA", "US", "QC".
    # * login is the Beanstream merchant ID, username and password should be enabled in your Beanstream account and passed in using the <tt>:user</tt> and <tt>:password</tt> options.
    # * Test your app with your true merchant id and test credit card information provided in the api pdf document.
    #  
    #  Example authorization (Beanstream PA transaction type):
    #  
    #   twenty = 2000
    #   gateway = BeanstreamGateway.new(
    #     :login => '100200000',
    #     :user => 'xiaobozz',
    #     :password => 'password'
    #   )
    #   
    #   credit_card = CreditCard.new(
    #     :number => '4030000010001234',
    #     :month => 8,
    #     :year => 2011,
    #     :first_name => 'xiaobo',
    #     :last_name => 'zzz',
    #     :verification_value => 137
    #   )
    #   response = gateway.authorize(twenty, credit_card,
    #     :order_id => '1234',
    #     :billing_address => {
    #       :name => 'xiaobo zzz',
    #       :phone => '555-555-5555',
    #       :address1 => '1234 Levesque St.',
    #       :address2 => 'Apt B',
    #       :city => 'Montreal',
    #       :state => 'QC',
    #       :country => 'CA',
    #       :zip => 'H2C1X8'
    #     },
    #     :email => 'xiaobozzz@example.com',
    #     :subtotal => 800,
    #     :shipping => 100,
    #     :tax1 => 100,
    #     :tax2 => 100,
    #     :custom => 'reference one'
    #   )
    class BeanstreamGateway < Gateway
      URL = 'https://www.beanstream.com/scripts/process_transaction.asp'

      TRANSACTIONS = {
        'authorization' => 'PA',
        'purchase'      => 'P',
        'capture'       => 'PAC'
      }

      CVD_CODES = {
        '1' => 'M',
        '2' => 'N',
        '3' => 'I',
        '4' => 'S',
        '5' => 'U',
        '6' => 'P'
      }

      AVS_CODES = {
        '0' => 'R',
        '5' => 'I',
        '9' => 'I'
      }
      
      self.default_currency = 'CAD'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.beanstream.com/'
      
      # The name of the gateway
      self.display_name = 'Beanstream.com'
      
      # Only <tt>:login</tt> is required by default, 
      # which is the merchant's merchant ID. If you'd like to perform void, 
      # capture or credit transactions then you'll also need to add a username
      # and password to your account under administration -> account settings ->
      # order settings -> Use username/password validation
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end
      
      def authorize(money, credit_card, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_address(post, options)        
        
        commit('authorization', money, post)
      end
      
      def purchase(money, credit_card, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_address(post, options)
             
        commit('purchase', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {}
        add_reference(post, authorization)
        add_amount(post, money)
        add_invoice(post, options)
        add_address(post, options)
        commit('capture', money, post)
      end

      private                       
      
      def add_amount(post, money)
        post[:trnAmount] = amount(money)
      end

      def add_reference(post, reference)
        post[:adjId] = reference
      end

      def add_address(post, options)      
        if billing_address = options[:billing_address] || options[:address]
          post[:ordName]          = billing_address[:name]
          post[:ordEmailAddress]  = options[:email]
          post[:ordPhoneNumber]   = billing_address[:phone]
          post[:ordAddress1]      = billing_address[:address1]
          post[:ordAddress2]      = billing_address[:address2]
          post[:ordCity]          = billing_address[:city]
          post[:ordProvince]      = billing_address[:state]
          post[:ordPostalCode]    = billing_address[:zip]
          post[:ordCountry]       = billing_address[:country]
        end
        if shipping_address = options[:shipping_address]
          post[:shipName]         = shipping_address[:name]
          post[:shipEmailAddress] = options[:email]
          post[:shipPhoneNumber]  = shipping_address[:phone]
          post[:shipAddress1]     = shipping_address[:address1]
          post[:shipAddress2]     = shipping_address[:address2]
          post[:shipCity]         = shipping_address[:city]
          post[:shipProvince]     = shipping_address[:state]
          post[:shipPostalCode]   = shipping_address[:zip]
          post[:shipCountry]      = shipping_address[:country]
          post[:shippingMethod]   = shipping_address[:method]
          post[:deliveryEstimate] = shipping_address[:delivery_estimate]
        end
      end

      def add_invoice(post, options)
        post[:trnOrderNumber]   = options[:order_id]
        post[:trnComments]      = options[:description]
        post[:ordItemPrice]     = amount(options[:subtotal])
        post[:ordShippingPrice] = amount(options[:shipping])
        post[:ordTax1Price]     = amount(options[:tax1] || options[:tax])
        post[:ordTax2Price]     = amount(options[:tax2])
      
        post[:ref1]             = options[:custom]
      end
      
      def add_credit_card(post, credit_card)
        post[:trnCardOwner] = credit_card.name
        post[:trnCardNumber] = credit_card.number
        post[:trnExpMonth] = format(credit_card.month, :two_digits)
        post[:trnExpYear] = format(credit_card.year, :two_digits)
        post[:trnCardCvd] = credit_card.verification_value
      end
      
      def parse(body)
        results = {}
        if !body.nil?
          body.split(/&/).each do |pair|
            key,val = pair.split(/=/)
            results[key.to_sym] = val.nil? ? nil : CGI.unescape(val)
          end
        end
        
        # Clean up the message text if there is any
        if results[:messageText]
          results[:messageText].gsub!(/<LI>/, "")
          results[:messageText].gsub!(/(\.)?<br>/, ". ")
          results[:messageText].strip!
        end
        
        results
      end
      
      def commit(action, money, parameters)
        response = parse(ssl_post(URL, post_data(action, parameters)))
        
        Response.new(success?(response), message_from(response), response,
          :test => test? || response[:authCode] == "TEST",
          :authorization => response[:trnId],
          :cvv_result => CVD_CODES[response[:cvdId]],
          :avs_result => { :code => (AVS_CODES.include? response[:avsId]) ? AVS_CODES[response[:avsId]] : response[:avsId] }
        )
      end

      def message_from(response)
        response[:messageText]
      end

      def success?(response)
        response[:trnApproved] == '1'
      end
      
      def post_data(action, parameters = {})
        parameters[:requestType] = 'BACKEND'
        parameters[:merchant_id] = @options[:login]
        parameters[:username] = @options[:user] if @options[:user]
        parameters[:password] = @options[:password] if @options[:password]
        parameters[:trnType] = TRANSACTIONS[action]
        parameters[:vbvEnabled] = '0'
        parameters[:scEnabled] = '0'
        
        parameters.reject{|k,v| v.blank?}.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

