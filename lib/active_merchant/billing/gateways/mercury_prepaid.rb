require File.dirname(__FILE__) + '/mercury/mercury_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercuryPrepaidGateway < Gateway
      include MercuryCommonAPI
      URLS = {
        :test => 'https://w1.mercurydev.net/ws/ws.asmx',
        :live => 'https://w1.mercurypay.com/ws/ws.asmx'
      }
      
      
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.mercurypay.com'
      
      # The name of the gateway
      self.display_name = 'Mercury'
      
      def issue(money, credit_card, options = {})
        request_body = build_non_authorized_request('Issue', money, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      def purchase(money, credit_card, options = {})
        request_body = build_non_authorized_request('NoNSFSale', money, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      # probably wont use this
      def sale(money, credit_card, options = {})
        request_body = build_non_authorized_request('Sale', money, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      def void(money, authorization, credit_card, options = {})
        options[:void] ||= 'VoidIssue'
        request_body = build_authorized_request(options[:void], money, authorization, credit_card, options )
        request = build_soap_request(request_body)
        commit(request)
      end
      
      def credit(money, credit_card, options = {})
        request_body = build_non_authorized_request('Return', money, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      def reload(money, credit_card, options = {})
        request_body = build_non_authorized_request('Reload', money, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      def balance(credit_card, options = {})
        request_body = build_non_authorized_request('Balance', 0, credit_card, options)
        request = build_soap_request(request_body)
        commit(request)
      end
      
      private
      
      def build_soap_request(body)
        xml = Builder::XmlMarkup.new
                
        xml.instruct!
        xml.tag! 'soap:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'soap:Body' do
            xml.tag! 'GiftTransaction', 'xmlns' => homepage_url do
              xml.tag! 'tran' do
                xml << body
              end
              xml.tag! 'pw', @options[:password]
            end
          end
        end
        xml.target!
      end
      
      def build_non_authorized_request(action, money, credit_card, options)
        requires!(options, :order_id, :invoice)
        
        xml = Builder::XmlMarkup.new
        
        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'PrePaid'
            xml.tag! 'TranCode', action
            xml.tag! 'IpPort', 9100
            add_invoice(xml, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card)
            # cvv data for gift cards is different than ccs
            xml.tag! "CVVData", options[:cvv_data] if options[:cvv_data]
          end
        end
        xml = xml.target!
        xml.gsub!(/\>/,'&gt;')
        xml.gsub!(/\</,'&lt;')
      end
      
      def build_authorized_request(action, money, authorization, credit_card, options)
        requires!(options, :order_id, :invoice)
        
        xml = Builder::XmlMarkup.new
        
        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'PrePaid'
            xml.tag! 'TranCode', action
            xml.tag! 'IpPort', 9100
            add_invoice(xml, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card)
            xml.tag! 'TranInfo' do
              xml.tag! "AuthCode", authorization
            end
          end
        end
        xml = xml.target!
        xml.gsub!(/\>/,'&gt;')
        xml.gsub!(/\</,'&lt;')
      end
      
      def add_invoice(xml, options)
        xml.tag! 'InvoiceNo', options[:invoice]
        xml.tag! 'RefNo', options[:order_id]
        xml.tag! 'OperatorID', options[:merchant] if options[:merchant]
        xml.tag! 'Memo', options[:description] if options[:description]
        xml.tag! 'Duplicate', options[:override] if options[:override]
      end
      
      def add_customer_data(xml, options)
        xml.tag! 'IpAddress', options[:ip] if options[:ip]
        xml.tag! 'MerchantID', @options[:login]
        
        if info = options[:demographics]
          xml.tag! 'DemographicInfo' do
            xml.tag! 'CustEmail', info[:email] if info[:email]
            xml.tag! 'CustName', info[:name] if info[:name]
            xml.tag! 'CustPhone', info[:phone] if info[:phone]
            xml.tag! 'CustAddr1', info[:addr1] if info[:addr1]
            xml.tag! 'CustAddr2', info[:addr2] if info[:addr2]
            xml.tag! 'CustCity', info[:city] if info[:city]
            xml.tag! 'CustState', info[:state] if info[:state]
            xml.tag! 'CustZip', info[:zip] if info[:zip]
            xml.tag! 'CustLanguage', info[:language] if info[:language]
          end
          
        end
      end
      
      def add_amount(xml, money, options = {})
        xml.tag! 'Amount' do
          xml.tag! 'Purchase', amount(money)
        end
      end
      
      def add_credit_card(xml, credit_card)
        xml.tag! 'Account' do
          if credit_card.is_a?(String)
            xml.tag! "Track2", credit_card
          else
            xml.tag! 'AcctNo', credit_card.number
          end
        end
        xml.tag! 'CardType', "OTHER"
      end
      
      def build_header
        {
          "SOAPAction" => "http://www.mercurypay.com/GiftTransaction",
          "Content-Type" => "text/xml; charset=utf-8"
        }
      end
      
      def parse(body)
        body.gsub!(/\&gt;/,'>')
        body.gsub!(/\&lt;/,'<')
        response = {}
        hashify_xml!(body, response)

        response
      end     
      
      def hashify_xml!(xml, response)
        xml = REXML::Document.new(xml)
        xml.elements.each("//CmdResponse/*") do |node|
          response[node.name.underscore.to_sym] = node.text
        end
        xml.elements.each("//TranResponse/*") do |node|

          if node.name.to_s == "Amount"
            node.elements.each do |amt|
              response[amt.name.underscore.to_sym] = amt.text
            end
          else
            response[node.name.underscore.to_sym] = node.text
          end
        end
      end
      
      def endpoint_url
        URLS[test? ? :test : :live]
      end
      
      def commit(request)
        response = parse(ssl_post(endpoint_url, request, build_header))
        
        success = SUCCESS_CODES.include?(response[:cmd_status])
        message = success ? 'Success' : message_from(response)

        Response.new(success, message, response,
          :test => test?,
          :authorization => response[:auth_code])
      end

      def message_from(response)
        response[:text_response]
      end
      
    end
  end
end