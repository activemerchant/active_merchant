module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This class is included in both PaypalGateway and PaypalExpressGateway
    module PaypalCommonAPI
      def self.included(base)
        
        base.default_currency = 'USD'
        base.cattr_accessor :pem_file
      end
      
      API_VERSION = '2.0'
      TEST_URL = 'https://api.sandbox.paypal.com/2.0/'
      LIVE_URL = 'https://api-aa.paypal.com/2.0/'
      
      PAYPAL_NAMESPACE = 'urn:ebay:api:PayPalAPI'
      EBAY_NAMESPACE = 'urn:ebay:apis:eBLBaseComponents'
      
      ENVELOPE_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                              'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                            }
      CREDENTIALS_NAMESPACES = { 'xmlns' => PAYPAL_NAMESPACE,
                                 'xmlns:n1' => EBAY_NAMESPACE,
                                 'env:mustUnderstand' => '0'
                               }
      
      AUSTRALIAN_STATES = {
        'ACT' => 'Australian Capital Territory',
        'NSW' => 'New South Wales',
        'NT'  => 'Northern Territory',
        'QLD' => 'Queensland',
        'SA'  => 'South Australia',
        'TAS' => 'Tasmania',
        'VIC' => 'Victoria',
        'WA'  => 'Western Australia'
      }
    
      # <tt>:pem</tt>         The text of your PayPal PEM file. Note
      #                       this is not the path to file, but its
      #                       contents. If you are only using one PEM
      #                       file on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      def initialize(options = {})
        requires!(options, :login, :password)
        
        @options = {
          :pem => self.class.pem_file
        }.update(options)
        
        super
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      def reauthorize(money, authorization, options = {})
        commit 'DoReauthorization', build_reauthorize_request(money, authorization, options)
      end
      
      def capture(money, authorization, options = {})
        commit 'DoCapture', build_capture_request(money, authorization, options)
      end
      
      # Transfer money to one or more recipients.
      #
      #   gateway.transfer 1000, 'bob@example.com',
      #     :subject => "The money I owe you", :note => "Sorry it's so late"
      #
      #   gateway.transfer [1000, 'fred@example.com'],
      #     [2450, 'wilma@example.com', :note => 'You will receive another payment on 3/24'],
      #     [2000, 'barney@example.com'],
      #     :subject => "Your Earnings", :note => "Thanks for your business."
      #
      def transfer(*args)
        commit 'MassPay', build_mass_pay_request(*args)
      end

      def void(authorization, options = {})
        commit 'DoVoid', build_void_request(authorization, options)
      end
      
      def credit(money, identification, options = {})
        commit 'RefundTransaction', build_credit_request(money, identification, options)
      end

      private
      def build_reauthorize_request(money, authorization, options)
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.tag! 'DoReauthorizationReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoReauthorizationRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
          end
        end

        xml.target!        
      end
          
      def build_capture_request(money, authorization, options)
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.tag! 'DoCaptureReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoCaptureRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
            xml.tag! 'CompleteType', 'Complete'
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!        
      end
      
      def build_credit_request(money, identification, options)
        xml = Builder::XmlMarkup.new :indent => 2
            
        xml.tag! 'RefundTransactionReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'RefundTransactionRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'TransactionID', identification
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
            xml.tag! 'RefundType', 'Partial'
            xml.tag! 'Memo', options[:note] unless options[:note].blank?
          end
        end
      
        xml.target!        
      end
      
      def build_void_request(authorization, options)
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.tag! 'DoVoidReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoVoidRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!        
      end
      
      def build_mass_pay_request(*args)
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        recipients = args.first.is_a?(Array) ? args : [args]
        
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.tag! 'MassPayReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'MassPayRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'EmailSubject', default_options[:subject] if default_options[:subject]
            recipients.each do |money, recipient, options|
              options ||= default_options
              xml.tag! 'MassPayItem' do
                xml.tag! 'ReceiverEmail', recipient
                xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
                xml.tag! 'Note', options[:note] if options[:note]
                xml.tag! 'UniqueId', options[:unique_id] if options[:unique_id]
              end
            end
          end
        end
        
        xml.target!
      end
      
      def parse(action, xml)
        response = {}
        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "//#{action}Response")
          root.elements.to_a.each do |node|
            case node.name
            when 'Errors'
              response[:message] = node.elements.to_a('//LongMessage').collect{|error| error.text}.join('.')
            else
              parse_element(response, node)
            end
          end
        elsif root = REXML::XPath.first(xml, "//SOAP-ENV:Fault")
          parse_element(response, root)
          response[:message] = "#{response[:faultcode]}: #{response[:faultstring]} - #{response[:detail]}"
        end

        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
          node.attributes.each do |k, v|
            response["#{node.name.underscore}_#{k.underscore}".to_sym] = v if k == 'currencyID'
          end
        end
      end

      def response_type_for(action)
        case action
        when 'Authorization', 'Purchase'
          'DoDirectPaymentResponse'
        when 'Void'
          'DoVoidResponse'
        when 'Capture'
          'DoCaptureResponse'
        end
      end

      def build_request(body)
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.instruct!
        xml.tag! 'env:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'env:Header' do
            add_credentials(xml)
          end
          
          xml.tag! 'env:Body' do
            xml << body
          end
        end
        xml.target!
      end
     
      def add_credentials(xml)
        xml.tag! 'RequesterCredentials', CREDENTIALS_NAMESPACES do
          xml.tag! 'n1:Credentials' do
            xml.tag! 'Username', @options[:login]
            xml.tag! 'Password', @options[:password]
            xml.tag! 'Subject', @options[:subject]
          end
        end
      end
      
      def add_address(xml, element, address)
        return if address.nil?
        xml.tag! element do
          xml.tag! 'n2:Name', address[:name]
          xml.tag! 'n2:Street1', address[:address1]
          xml.tag! 'n2:Street2', address[:address2]
          xml.tag! 'n2:CityName', address[:city]
          xml.tag! 'n2:StateOrProvince', lookup_state(address)
          xml.tag! 'n2:Country', address[:country]
          xml.tag! 'n2:PostalCode', address[:zip]
          xml.tag! 'n2:Phone', address[:phone]
        end
      end
      
      def lookup_state(address)
        country = Country.find(address[:country]) rescue nil
        return '' if country.nil?
        
        case country.code(:alpha2).to_s
        when 'AU'
          AUSTRALIAN_STATES[address[:state]] || address[:state] 
        when 'GB'
          address[:state].blank? ? 'N/A' : address[:state] 
        else
          address[:state]
        end
      end

      def commit(action, request)
        url = test? ? TEST_URL : LIVE_URL

        data = ssl_post(url, build_request(request))
        @response = parse(action, data)
       
        success = @response[:ack] == "Success"
        message = @response[:message] || @response[:ack]

        build_response(success, message, @response,
    	    :test => test?,
    	    :authorization => @response[:transaction_id] || @response[:authorization_id] # latter one is from reauthorization
        )
      end
    end
  end
end