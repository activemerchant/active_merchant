module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This class is an abstract base class for both PaypalGateway and
    # PaypalExpressGateway
    module PaypalCommonAPI
      def self.included(base)
        base.cattr_accessor :pem_file
      end
      
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

      def capture(money, authorization, options = {})
        commit 'DoCapture', build_capture_request(money, authorization, options)
      end

      def void(authorization, options = {})
        commit 'DoVoid', build_void_request(authorization, options)
      end
      
      def credit(money, identification, options = {})
        commit 'RefundTransaction', build_credit_request(money, identification, options)
      end

      private
          
      def build_capture_request(money, authorization, options)
        xml = Builder::XmlMarkup.new :indent => 2
        
        xml.tag! 'DoCaptureReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoCaptureRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', '2.0'
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => currency(money)
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
            xml.tag! 'n2:Version', '2.0'
            xml.tag! 'TransactionID', identification
            xml.tag! 'Amount', amount(money), 'currencyID' => currency(money)
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
            xml.tag! 'n2:Version', '2.0'
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!        
      end
      
      def ssl_post(data)
        uri = URI.parse(test? ? TEST_URL : LIVE_URL)

        http = Net::HTTP.new(uri.host, uri.port)

        http.verify_mode    = OpenSSL::SSL::VERIFY_PEER
        http.use_ssl        = true
        http.cert           = OpenSSL::X509::Certificate.new(@options[:pem])
        http.key            = OpenSSL::PKey::RSA.new(@options[:pem])
        http.ca_file        = File.dirname(__FILE__) + '/api_cert_chain.crt'

        http.post(uri.path, data).body
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
      
      def add_address(xml, address)
        return if address.nil?
        xml.tag! 'n2:Address' do
          xml.tag! 'n2:Name', address[:name]
          xml.tag! 'n2:Street1', address[:address1]
          xml.tag! 'n2:Street2', address[:address2]
          xml.tag! 'n2:CityName', address[:city]
          xml.tag! 'n2:StateOrProvince', address[:state]
          xml.tag! 'n2:Country', address[:country]
          xml.tag! 'n2:PostalCode', address[:zip]
          xml.tag! 'n2:Phone', address[:phone]
        end
      end

      def currency(money)
        money.respond_to?(:currency) ? money.currency : 'USD'
      end
      
      def commit(action, request)
        data = ssl_post build_request(request)
        
        @response = parse(action, data)
       
        success = @response[:ack] == "Success"
        message = @response[:message] || @response[:ack]

        build_response(success, message, @response,
    	    :test => test?,
    	    :authorization => @response[:transaction_id]
        )
      end
    end
  end
end
