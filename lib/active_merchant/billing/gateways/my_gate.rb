require File.dirname(__FILE__) + '/my_gate/security_pre_auth_response'
require File.dirname(__FILE__) + '/my_gate/security_auth_response'
require File.dirname(__FILE__) + '/my_gate/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # MyGate is a South African payment solutions company providing a Payment Gateway.
    # 
    # For more information on the MyGate Payment Gateway please visit the {product page}[http://mygate.co.za/products/payment-gateway].
    # 
    # The process for transacting with MyGate is as follows:
    # 
    # * Once you receive the credit card details run a <tt>security_pre_auth</tt> on the MyGateGateway instance.
    #   This will tell you whether the user is registered for 3D-Secure and if so, where to redirect them
    #   in order for them to enter their PIN.
    # * If they are enrolled redirect them to the <tt>acs_url</tt> provided by POSTing the paramaters
    #   documented in +MyGate::SecurityPreAuthResponse+.
    # * Once they successfully enter their PIN they will be redirected to the URL you provided which
    #   should point to a controller that passes the params directly to <tt>process_acs</tt>. This will
    #   authenticate what they entered into 3D-Secure with MyGate.
    # * If this is successful or if they weren't enrolled you should now have a valid <tt>transaction_index</tt>
    #   in order to submit the <tt>purchase</tt> or other transaction much like other gateways.
    # 
    # Please take note that some of the responses have slightly modified behaviour, e.g. <tt>purchase</tt>
    # returns an <tt>Array</tt> of authorizations as it effectively does an <tt>authorize</tt> and <tt>capture</tt>
    # on the MyGate platform. Also the <tt>transaction_index</tt> is used as the authorization for captures, 
    # not the <tt>authorization</tt> Array.
    class MyGateGateway < Gateway
      
      # This is the version of the API the gateway is implemented against
      API_VERSION = '5.0.0'
      def self.api_version; API_VERSION.gsub '.', 'x'; end #:nodoc:
      
      # # # # # # # # # # # # # # # # # # # # # #
      #                Constants                #
      # # # # # # # # # # # # # # # # # # # # # #
      
      # The location of the web services required to interact with MyGate
      URLS = {
        :three_d_secure => 'https://www.mygate.co.za/3dsecure/3DSecure.cfc',
        :transaction => "https://www.mygate.co.za/enterprise/#{api_version}/ePayService.cfc",
        :immediate_settlement => "https://www.mygate.co.za/enterprise/#{api_version}/ePayWebService.cfc"
      }
      
      # Used to map actions to the various Web Services
      SERVICES = {
        :security_pre_auth => :three_d_secure,
        :security_auth     => :three_d_secure,
        :authorize         => :transaction,
        :void              => :transaction,
        :capture           => :transaction,
        :refund            => :transaction,
        :purchase          => :immediate_settlement
      }
      
      # Used to list the supported cards and map them to the codes used by MyGate
      CARD_TYPES = {
        :american_express => '1',
        :discover         => '2',
        :master           => '3',
        :visa             => '4',
        :diners_club      => '5'
      }
      
      # Used to map the bank name where the merchant account is kept to a code for use by MyGate
      MERCHANT_GATEWAYS = {
        :fnb_live       => '21',
        :absa           => '22',
        :nedbank        => '23',
        :standard_bank  => '24'
      }
      
      # Used to map the transaction types to codes used by MyGate
      ACTIONS = {
        :authorize          => '1',
        :reverse_authorize  => '2',
        :settlement         => '3',
        :refund             => '4'
      }
      SOAP_ACTIONS = {
        :security_pre_auth  => 'lookup',
        :security_auth      => 'authenticate',
        :authorize          => 'fProcess',
        :capture            => 'fProcess',
        :reverse_authorize  => 'fProcess',
        :settlement         => 'fProcess',
        :refund             => 'fProcess',
        :purchase           => ''
      }
      
      # # # # # # # # # # # # # # # # # # # # # #
      #              Configuration              #
      # # # # # # # # # # # # # # # # # # # # # #
      
      self.supported_countries = ['ZA']
      self.supported_cardtypes = CARD_TYPES.keys
      self.homepage_url = 'http://mygate.co.za/'
      self.display_name = 'MyGate'
      self.default_currency = 'ZAR'
      
      # Creates a new MyGateGateway
      #
      # Unlike other gateways you are required to pass the following in the options hash:
      # 
      # ==== Options
      #
      # * <tt>:gateway_id</tt> -- The bank where the merchant account is kept. Must be one of the following: 
      #                           <tt><:fnb_live/tt>, <tt>:absa</tt>, <tt>:nedbank</tt> or <tt>:standard_bank</tt> (REQUIRED)
      # * <tt>:application_id</tt> -- The MyGate Application ID. Looks like: +4b775479-a264-444c-b774-22d5521852d8+ (REQUIRED)
      # * <tt>:merchant_id</tt> -- The MyGate Merchant ID. Looks like: +79958a8d-0c7b-4038-8e2e-8948e1d678e1+ (REQUIRED)
      # 
      def initialize(options = {})
        requires!(options, :merchant_id, :application_id, :gateway)
        @options = options
        super
      end
      
      # # # # # # # # # # # # # # # # # # # # # #
      # Specialized Methods for Authentication  #
      # # # # # # # # # # # # # # # # # # # # # #
      
      # This method is called to initiate the 3D-Secure verification process. It is the
      # first in a 3 step process to obtain a TransactionIndex which MyGate requires
      # for the regular gateway actions.
      # 
      # This method returns a <tt>MyGate::SecurityPreAuthResponse</tt> object which will
      # contain the parameters which should be used when posted to the 3D-Secure server.
      # See that class for documentation.
      # 
      # ==== Parameters
      # 
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      # 
      # ==== Required Options
      # 
      # * <tt>:user_agent</tt> -- The user agent of the user's browser.
      # * <tt>:http_accept</tt> -- The HTTPAccept header sent by the user's browser. (use '*/*' if unsure)
      # 
      def security_pre_auth(money, creditcard, options = {})
        requires!(options, :user_agent, :http_accept)
        
        options.reverse_merge(:recurring => 'N') # defaults
        
        xml = Builder::XmlMarkup.new(:indent => 2, :margin => 3)
        
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        add_field_to xml, 'Mode', test? ? '0' : '1'
        
        add_field_to xml, 'PAN', creditcard.number
        add_field_to xml, 'PANExpr', "#{format(creditcard.year, :two_digits)}#{format(creditcard.month, :two_digits)}"
        add_field_to xml, 'PurchaseAmount', amount(money)
        
        add_field_to xml, 'UserAgent', options[:user_agent]
        add_field_to xml, 'BrowserHeader', options[:http_accept]
        
        add_field_to xml, 'OrderNumber', options[:order_id]
        add_field_to xml, 'OrderDesc', options[:description]
        
        add_field_to xml, 'Recurring', options[:recurring]
        add_field_to xml, 'RecurringFrequency', options[:recurring_day]
        add_field_to xml, 'RecurringEnd', options[:recurring_end]
        add_field_to xml, 'Installment', options[:installment]
        
        MyGate::SecurityPreAuthResponse.new commit(:security_pre_auth, xml.target!)
      end
      
      # Process the response from the ACS service and verify it with MyGate
      # 
      # This method should be called in an action to which the ACS service posted
      # its response. This action should have access to the original order information
      # in order to retrieve the details of the transaction and process the transaction
      # once the authentication has completed.
      # 
      # It returns a <tt>MyGate::SecurityAuthResponse</tt>.
      # 
      # ==== Parameters
      # 
      # * <tt>params</tt> -- The params hash that the controller action received.
      # * <tt>options</tt> -- Should contain the <tt>:transaction_index</tt> from the <tt>SecurityPreAuthResponse</tt>.
      # 
      def security_auth(params, options = {})
        requires!(params, 'PaRes')
        requires!(options, :transaction_index)
        
        xml = Builder::XmlMarkup.new(:indent => 2, :margin => 3)
        
        add_field_to xml, 'TransactionID', options[:transaction_index]
        add_field_to xml, 'PAResPayload', params['PaRes']
        
        MyGate::SecurityAuthResponse.new commit(:security_auth, xml.target!)
      end
      
      # # # # # # # # # # # # # # # # # # # # # #
      #        Standard Gateway Functions       #
      # # # # # # # # # # # # # # # # # # # # # #
      
      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      # 
      # * <tt>money</tt> -- the Integer amount to be purchased in cents
      # * <tt>creditcard</tt> -- the CreditCard details for the transaction
      # * <tt>options</tt> -- a Hash of optional parameters
      # 
      # ==== Required Options
      # 
      # <tt>transaction_index</tt> -- provided by 3D-Secure operation (required)
      # 
      def purchase(money, creditcard, options = {})
        requires!(options, :transaction_index)
        address = options[:shipping_address] || options[:address]
        
        xml = Builder::XmlMarkup.new :indent => 2, :margin => 3
        
        add_field_to xml, 'GatewayID', MERCHANT_GATEWAYS[@options[:gateway].to_sym]
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        
        add_field_to xml, 'TransactionIndex', options[:transaction_index]
        add_field_to xml, 'Terminal', options[:merchant] || application_id
        add_field_to xml, 'Mode', test? ? 0 : 1
        add_field_to xml, 'MerchantReference', options[:order_id]
        add_field_to xml, 'Amount', amount(money)
        add_field_to xml, 'Currency', options[:currency] || currency(money)
        add_field_to xml, 'CashBackAmount'
        add_field_to xml, 'CardType', CARD_TYPES[creditcard.type.to_sym]
        add_field_to xml, 'AccountType'
        add_field_to xml, 'CardNumber', creditcard.number
        add_field_to xml, 'CardHolder', creditcard.name || options[:customer]
        add_field_to xml, 'CVVNumber', creditcard.verification_value
        add_field_to xml, 'ExpiryMonth', format(creditcard.month, :two_digits)
        add_field_to xml, 'ExpiryYear', format(creditcard.year, :four_digits)
        add_field_to xml, 'Budget'
        add_field_to xml, 'BudgetPeriod'
        add_field_to xml, 'AuthorisationNumber'
        add_field_to xml, 'PIN'
        add_field_to xml, 'DebugMode'
        add_field_to xml, 'eCommerceIndicator'
        add_field_to xml, 'verifiedByVisaXID', options[:xid]
        add_field_to xml, 'verifiedByVisaCAFF', options[:caff]
        add_field_to xml, 'secureCodeUCAF'
        add_field_to xml, 'UCI'
        add_field_to xml, 'IPAddress', options[:ip]
        add_field_to xml, 'ShippingCountryCode', address && address[:country]
        add_field_to xml, 'PurchaseItemsID'
        
        MyGate::Response.new(commit(:purchase, xml.target!), :test => test?)
      end
      
      # Perform an authorization (see if the funds are available)
      # 
      # ==== Parameters
      # 
      # * <tt>money</tt> -- the Integer amount to be purchased in cents
      # * <tt>creditcard</tt> -- the CreditCard details for the transaction
      # * <tt>options</tt> -- a Hash of optional parameters
      # 
      # ==== Required Options
      # 
      # <tt>transaction_index</tt> -- provided by 3D-Secure operation (required)
      # 
      def authorize(money, creditcard, options = {})
        requires!(options, :transaction_index)
        address = options[:shipping_address] || options[:address]
        
        xml = Builder::XmlMarkup.new :indent => 2, :margin => 3
        
        add_field_to xml, 'GatewayID', MERCHANT_GATEWAYS[@options[:gateway].to_sym]
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        
        add_field_to xml, 'Action', ACTIONS[:authorize]
        add_field_to xml, 'TransactionIndex', options[:transaction_index]
        add_field_to xml, 'Terminal', options[:merchant] || application_id
        add_field_to xml, 'Mode', (test? ? '0' : '1')
        add_field_to xml, 'MerchantReference', options[:order_id]
        add_field_to xml, 'Amount', amount(money)
        add_field_to xml, 'Currency', options[:currency] || currency(money)
        add_field_to xml, 'CashBackAmount'
        add_field_to xml, 'CardType', CARD_TYPES[creditcard.type.to_sym]
        add_field_to xml, 'AccountType'
        add_field_to xml, 'CardNumber', creditcard.number
        add_field_to xml, 'CardHolder', creditcard.name || options[:customer]
        add_field_to xml, 'CVVNumber', creditcard.verification_value
        add_field_to xml, 'ExpiryMonth', format(creditcard.month, :two_digits)
        add_field_to xml, 'ExpiryYear', format(creditcard.year, :four_digits)
        add_field_to xml, 'Budget'
        add_field_to xml, 'BudgetPeriod'
        add_field_to xml, 'AuthorisationNumber'
        add_field_to xml, 'PIN'
        add_field_to xml, 'DebugMode'
        add_field_to xml, 'eCommerceIndicator'
        add_field_to xml, 'verifiedByVisaXID', options[:xid]
        add_field_to xml, 'verifiedByVisaCAFF', options[:caff]
        add_field_to xml, 'secureCodeUCAF'
        add_field_to xml, 'UCI', options[:uci]
        add_field_to xml, 'IPAddress', options[:ip]
        add_field_to xml, 'ShippingCountryCode', address && address[:country]
        add_field_to xml, 'PurchaseItemsID'
        
        MyGate::Response.new(commit(:authorize, xml.target!), :test => test?)
      end
      
      # Reverse an authorization
      # 
      # ==== Parameters
      # 
      # * <tt>amount</tt> -- the (currently optional) amount previously authorized
      # * <tt>authorize_transaction_index</tt> -- the <tt>transaction_index</tt> from the authorization call
      # * <tt>options</tt> -- a Hash of optional parameters
      # 
      def void(amount, authorize_transaction_index, options = {})
        xml = Builder::XmlMarkup.new :indent => 2, :margin => 3
        
        add_field_to xml, 'GatewayID', MERCHANT_GATEWAYS[@options[:gateway].to_sym]
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        
        add_field_to xml, 'Action', ACTIONS[:reverse_authorize]
        add_field_to xml, 'TransactionIndex', authorize_transaction_index
        add_field_to xml, 'Terminal', options[:merchant] || application_id
        add_field_to xml, 'Mode' #, (test? ? '0' : '1') # Test mode causes warnings
        add_field_to xml, 'MerchantReference', options[:order_id]
        add_field_to xml, 'Amount'
        
        add_unused_action_fields_to xml, options[:ip]
        
        MyGate::Response.new(commit(:capture, xml.target!), :test => test?)
      end
      
      # Perform a capture (transfer the funds)
      # 
      # ==== Parameters
      # 
      # * <tt>money</tt> -- the Integer amount to be captured in cents
      # * <tt>authorize_transaction_index</tt> -- the <tt>transaction_index</tt> from the <tt>authorize</tt> response
      # * <tt>options</tt> -- a Hash of optional parameters
      # 
      def capture(money, authorize_transaction_index, options = {})
        xml = Builder::XmlMarkup.new :indent => 2, :margin => 3
        
        add_field_to xml, 'GatewayID', MERCHANT_GATEWAYS[@options[:gateway].to_sym]
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        
        add_field_to xml, 'Action', ACTIONS[:settlement]
        add_field_to xml, 'TransactionIndex', authorize_transaction_index
        add_field_to xml, 'Terminal', options[:merchant] || application_id
        add_field_to xml, 'Mode' #, (test? ? '0' : '1') # Test mode causes warnings
        add_field_to xml, 'MerchantReference', options[:order_id]
        add_field_to xml, 'Amount', amount(money)
        
        add_unused_action_fields_to xml, options[:ip]
        
        MyGate::Response.new(commit(:capture, xml.target!), :test => test?)
      end
      
      # Refund a customer for a specific capture
      # 
      # ==== Parameters
      # 
      # * <tt>money</tt> -- the Integer amount to be refunded in cents
      # * <tt>capture_transaction_index</tt> -- the <tt>transaction_index</tt> that was returned by the <tt>capture</tt> and the <tt>authorize</tt> calls
      # * <tt>options</tt> -- a Hash of optional parameters
      # 
      def refund(money, capture_transaction_index, options = {})
        xml = Builder::XmlMarkup.new :indent => 2, :margin => 3
        
        add_field_to xml, 'GatewayID', MERCHANT_GATEWAYS[@options[:gateway].to_sym]
        add_field_to xml, 'MerchantID', @options[:merchant_id]
        add_field_to xml, 'ApplicationID', @options[:application_id]
        
        add_field_to xml, 'Action', ACTIONS[:refund]
        add_field_to xml, 'TransactionIndex', capture_transaction_index
        add_field_to xml, 'Terminal', options[:merchant] || application_id
        add_field_to xml, 'Mode' #, (test? ? '0' : '1') # Test mode causes warnings
        add_field_to xml, 'MerchantReference', options[:order_id]
        add_field_to xml, 'Amount' #, amount(money) # Amount causes warnings
        
        add_unused_action_fields_to xml, options[:ip]
        
        MyGate::Response.new(commit(:capture, xml.target!), :test => test?)
      end
      
      private
      
      # To remove some duplication that is semantically irrelevant
      def add_unused_action_fields_to(xml, ip_address = nil)
        add_field_to xml, 'Currency'
        add_field_to xml, 'CashBackAmount'
        add_field_to xml, 'CardType'
        add_field_to xml, 'AccountType'
        add_field_to xml, 'CardNumber'
        add_field_to xml, 'CardHolder'
        add_field_to xml, 'CVVNumber'
        add_field_to xml, 'ExpiryMonth'
        add_field_to xml, 'ExpiryYear'
        add_field_to xml, 'Budget'
        add_field_to xml, 'BudgetPeriod'
        add_field_to xml, 'AuthorisationNumber'
        add_field_to xml, 'PIN'
        add_field_to xml, 'DebugMode'
        add_field_to xml, 'eCommerceIndicator'
        add_field_to xml, 'verifiedByVisaXID'
        add_field_to xml, 'verifiedByVisaCAFF'
        add_field_to xml, 'secureCodeUCAF'
        add_field_to xml, 'UCI'
        add_field_to xml, 'IPAddress', ip_address
        add_field_to xml, 'ShippingCountryCode'
        add_field_to xml, 'PurchaseItemsID'
      end
      
      # This wraps the parameters for all the transactions into a SOAP wrapper to be sent to the web service
      # 
      # ==== Parameters
      #
      # * <tt>action</tt> -- The transaction type to build (matching the gateway actions) as a symbol.
      # * <tt>body</tt> -- A Builder::XmlMarkup instance containing the tags to wrap in a SOAP envelope.
      # 
      def build_request(action, body)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 's:Envelope', { 'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/',
                                 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 
                                 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance' } do
          xml.tag! 's:Body', { 'xmlns:api' => namespace_from(action) } do
            
            xml.tag! "api:#{root_node_from(action)}" do
              xml << body
            end
          end
        end
      end
      
      # Used internally to DRY up the process of adding parameters to the SOAP request.
      # Calling it without a value will cause opening and closing tags to be present,
      # but without any content. Many parameters are required to be sent in this way.
      # 
      # ==== Parameters
      #
      # * <tt>xml</tt> -- The Builder::XmlMarkup instance to add the tag to. (required)
      # * <tt>field</tt> -- The name of the parameter as a string or symbol. (required)
      # * <tt>value</tt> -- Optional String content of the tag.
      # 
      def add_field_to(xml, field, value = '')
        xml.tag! field.to_s, { }, value
      end
      
      # # # # # # # # # # # # # # # # # # # # # #
      #           Gateway Communication         #
      # # # # # # # # # # # # # # # # # # # # # #
      
      # Send the request to MyGate and parse a response
      # 
      # ==== Parameters
      #
      # * <tt>action</tt> -- The transaction type to build (matching the gateway actions) as a symbol.
      # * <tt>body</tt> -- A Builder::XmlMarkup instance containing the tags to insert into the SOAP request.
      # 
      def commit(action, body, verbose_mode = false)
        request = build_request(action, body)
        puts "\n\n#{request}\n\n" if verbose_mode
        url = URLS[SERVICES[action]]
        response = ssl_post(url, request, {'Content-Type' => 'text/xml; charset=utf-8', 'SOAPAction' => SOAP_ACTIONS[action]})
        puts "\n\n#{response}\n\n" if verbose_mode
        response
      end
      
      def root_node_from(action)
        case action
        when :purchase
          'fProcessAndSettle'
        when :security_pre_auth
          'lookup'
        when :security_auth
          'authenticate'
        else
          'fProcess'
        end
      end
      
      def namespace_from(action)
        case action
        when :security_pre_auth, :security_auth
          'http://_3dsecure'
        else
          "http://_#{self.class.api_version}.enterprise"
        end
      end
      
    end
  end
end

