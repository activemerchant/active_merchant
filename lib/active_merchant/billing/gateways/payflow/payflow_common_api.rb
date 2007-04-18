module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PayflowCommonAPI
      def self.included(base)
        base.class_inheritable_accessor :default_currency
        base.default_currency = 'USD'
          
        # The certification_id is required by PayPal to make direct HTTPS posts to their servers.
        # You can obtain a certification id by emailing: payflowintegrator@paypal.com
        base.class_inheritable_accessor :certification_id
        base.class_inheritable_accessor :partner
        
        # Set the default partner to PayPal
        base.partner = 'PayPal'
      end
      
      XMLNS = 'http://www.paypal.com/XMLPay'
      TEST_URL = 'https://pilot-payflowpro.verisign.com/transaction'
      LIVE_URL = 'https://payflowpro.verisign.com/transaction'
      
      CARD_MAPPING = {
        :visa => 'Visa',
        :master => 'MasterCard',
        :discover => 'Discover',
        :american_express => 'Amex',
        :jcb => 'JCB',
        :diners_club => 'DinersClub',
        :switch => 'Switch',
        :solo => 'Solo'
      }
          
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = {
          :certification_id => self.class.certification_id,
          :partner => self.class.partner
        }.update(options)
        
        super
      end  
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      def capture(money, authorization, options = {})
        request = build_void_or_capture_request('Capture', authorization)
        commit(request)
      end
      
      def void(authorization, options = {})
        request = build_void_or_capture_request('Void', authorization)
        commit(request)
      end
         
      private      
      def build_request(body)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'XMLPayRequest', 'Timeout' => 30, 'version' => "2.1", "xmlns" => XMLNS do
          xml.tag! 'RequestData' do
            xml.tag! 'Vendor', @options[:login]
            xml.tag! 'Partner', @options[:partner]
            xml.tag! 'Transactions' do
              xml.tag! 'Transaction' do
                xml.tag! 'Verbosity', 'MEDIUM'
                xml << body
              end
            end
          end
          xml.tag! 'RequestAuth' do
            xml.tag! 'UserPass' do
              xml.tag! 'User', @options[:login]
              xml.tag! 'Password', @options[:password]
            end
          end
        end
        xml.target!
      end
      
      def build_void_or_capture_request(action, authorization)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! action do
          xml.tag! 'PNRef', authorization
        end
        xml.target!
      end
            
      def add_paypal_details(xml, options)
        xml.tag! 'PayPal' do
          xml.tag! 'EMail', options[:email]
          xml.tag! 'ReturnURL', options[:return_url]
          xml.tag! 'CancelURL', options[:cancel_return_url]
        end
      end

      def add_address(xml, tag, address, options)  
        return if address.nil?
        xml.tag! tag do
          xml.tag! 'Name', address[:name] unless options[:name].blank?
          xml.tag! 'Email', options[:email] unless options[:email].blank?
          xml.tag! 'Phone', address[:phone] unless address[:phone].blank?
          xml.tag! 'Address' do
            xml.tag! 'Street', address[:address1] unless address[:address1].blank?
            xml.tag! 'City', address[:city] unless address[:city].blank?
            xml.tag! 'State', address[:state] unless address[:state].blank?
            xml.tag! 'Country', address[:country] unless address[:country].blank?
            xml.tag! 'Zip', address[:zip] unless address[:zip].blank?
          end
        end
      end
          
      def parse(data)
        response = {}
        xml = REXML::Document.new(data)
        root = REXML::XPath.first(xml, "//ResponseData")
        
        if REXML::XPath.first(root, "//TransactionResult/attribute::Duplicate")
          response[:duplicate] = true 
        end
        
        root.elements.to_a.each do |node|
          parse_element(response, node)
        end

        response
      end
      
      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
      def build_headers(content_length)
        {
          "Content-Type" => "text/xml",
          "Content-Length" => content_length.to_s,
      	  "X-VPS-Timeout" => "30",
      	  "X-VPS-VIT-Client-Certification-Id" => @options[:certification_id].to_s,
      	  "X-VPS-VIT-Integration-Product" => "ActiveMerchant",
      	  "X-VPS-VIT-Runtime-Version" => RUBY_VERSION,
      	  "X-VPS-Request-ID" => generate_unique_id
    	  }
    	end
    	
    	def commit(request_body)
        request = build_request(request_body)
        headers = build_headers(request_body.size)
    	  
    	  url = test? ? TEST_URL : LIVE_URL
    	  data = ssl_post(url, request, headers)
    	  @response = parse(data)
    	  
    	  success = @response[:result] == "0"
    	  message = @response[:message]
    	  
    	  build_response(success, message, @response,
    	    :test => test?,
    	    :authorization => @response[:pn_ref]
        )
      end
    end
  end
end