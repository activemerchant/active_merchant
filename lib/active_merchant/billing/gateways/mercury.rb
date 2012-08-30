require File.dirname(__FILE__) + '/mercury/mercury_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercuryGateway < Gateway
      include MercuryCommonAPI
      
      URLS = {
        :test => 'https://w1.mercurydev.net/ws/ws.asmx',
        :live => 'https://example.com/live'
      }
      
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.mercurypay.com'
      
      # The name of the gateway
      self.display_name = 'Mercury'
      
      
      def purchase(money, credit_card, options = {})
        request_body = build_non_authorized_request('Sale', money, credit_card, options)
        request = build_soap_request(request_body)
        commit('Sale', request)
      end
      
      def credit(money, credit_card, options = {})
        # cvv does nothing
        credit_card.verification_value = nil
        request_body = build_non_authorized_request('Return', money, credit_card, options)
        request = build_soap_request(request_body)
        commit('Return', request)
      end
      
      def void(money, authorization, credit_card, options = {})
        options[:void] ||= 'VoidSale'
        request_body = build_authorized_request(options[:void], money, authorization, credit_card, options)
        request = build_soap_request(request_body)
        commit(options[:void], request)
      end
      
      def authorize(money, credit_card, options = {})
        options[:authorized] ||= money
        request_body = build_non_authorized_request('PreAuth', money, credit_card, options)
        request = build_soap_request(request_body)
        commit('PreAuth', request)
      end
      
      def capture(money, authorization, credit_card, options = {})
        options[:authorized] ||= money
        # cant send cvv data, so strip it to be sure
        credit_card.verification_value = nil
        request_body = build_authorized_request('PreAuthCapture', money, authorization, credit_card, options)
        request = build_soap_request(request_body)
        commit('PreAuthCapture', request)
      end
      
      def voice_authorize(money, authorization, credit_card, options = {})
        request_body = build_authorized_request('VoiceAuth', money, authorization, credit_card, options)
        request = build_soap_request(request_body)
        commit('VoiceAuth', request)
      end
      
      def adjust(money, authorization, credit_card, options = {})
        request_body = build_authorized_request('Adjust', money, authorization, credit_card, options)
        request = build_soap_request(request_body)
        commit('Adjust', request)
      end
      
      def batch_summary
        xml = Builder::XmlMarkup.new
        
        xml.tag! "TStream" do
          xml.tag! "Admin" do
            xml.tag! 'TranCode', 'BatchSummary'
          end
          xml.tag! 'MerchantID', @options[:login]
        end
        xml = xml.target!
        xml.gsub!(/\>/,'&gt;')
        xml.gsub!(/\</,'&lt;')
        
        request = build_soap_request(xml)
        commit('BatchSummary', request)
      end
      
      def batch_close(options = {})
        requires!(options, :batch_no, :batch_item_count, :net_batch_total,
          :credit_purchase_count, :credit_purchase_amount, :credit_return_count,
          :credit_return_amount, :debit_purchase_count, :debit_purchase_amount,
          :debit_return_count, :debit_return_amount)
        # need a lot of options for this one
        xml = Builder::XmlMarkup.new
        
        xml.tag! "TStream" do
          xml.tag! "Admin" do
            xml.tag! 'TranCode', 'BatchClose'
          end
          xml.tag! 'MerchantID', @options[:login]
          xml.tag! "BatchNo", options[:batch_no]
          xml.tag! "BatchItemCount", options[:batch_item_count]
          xml.tag! "NetBatchTotal", options[:net_batch_total]
          xml.tag! "CreditPurchaseCount", options[:credit_purchase_count]
          xml.tag! "CreditPurchaseAmount", options[:credit_purchase_amount]
          xml.tag! "CreditReturnCount", options[:credit_return_count]
          xml.tag! "CreditReturnAmount", options[:credit_return_amount]
          xml.tag! "DebitPurchaseCount", options[:debit_purchase_count]
          xml.tag! "DebitPurchaseAmount", options[:debit_purchase_amount]
          xml.tag! "DebitReturnCount", options[:debit_return_count]
          xml.tag! "DebitReturnAmount", options[:debit_return_amount]
        end
        xml = xml.target!
        xml.gsub!(/\>/,'&gt;')
        xml.gsub!(/\</,'&lt;')
        
        request = build_soap_request(xml)
        commit('BatchClose', request)
      end
      
      private
      
      def build_soap_request(body)
        xml = Builder::XmlMarkup.new
                
        xml.instruct!
        xml.tag! 'soap:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'soap:Body' do
            xml.tag! 'CreditTransaction', 'xmlns' => homepage_url do
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
            xml.tag! 'TranType', 'Credit'
            xml.tag! 'TranCode', action
            if action == 'PreAuth' || action == 'Sale'
              xml.tag! "PartialAuth", "Allow"
            end
            add_invoice(xml, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card)
            add_address(xml, options)
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
            xml.tag! 'TranType', 'Credit'
            xml.tag! 'TranCode', action
            if action == 'PreAuthCapture'
              xml.tag! "PartialAuth", "Allow"
            end
            add_invoice(xml, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            # captures cannot contain track2 data
            add_credit_card(xml, credit_card) unless credit_card.is_a?(String)
            add_address(xml, options)
            xml.tag! 'TranInfo' do
              xml.tag! "AuthCode", authorization
              xml.tag! "AcqRefData", options[:acq_ref_data] if options[:acq_ref_data]
              xml.tag! "ProcessData", options[:process_data] if options[:process_data]
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
      end
      
      def add_customer_data(xml, options)
        xml.tag! 'IpAddress', options[:ip] if options[:ip]
        if options[:customer]
          xml.tag! "TranInfo" do
            xml.tag! 'CustomerCode', options[:customer]
          end
        end
        xml.tag! 'MerchantID', @options[:login]
      end
      
      def add_amount(xml, money, options = {})
        xml.tag! 'Amount' do
          xml.tag! 'Purchase', amount(money)
          xml.tag! 'Tax', options[:tax] if options[:tax]
          xml.tag! 'Authorize', amount(options[:authorized]) if options[:authorized]
          xml.tag! 'Gratuity', amount(options[:tip]) if options[:tip]
        end
      end
      
      def add_credit_card(xml, credit_card)
        # track2 data should NOT have sentinel values
        if credit_card.is_a?(String)
          xml.tag! 'Account' do
            xml.tag! "Track2", credit_card
          end
        else
          xml.tag! 'Account' do
            xml.tag! 'AcctNo', credit_card.number
            xml.tag! 'ExpDate', expdate(credit_card)
          end
          xml.tag! 'CardType', CARD_CODES[credit_card.brand] if credit_card.brand
          xml.tag! 'CVVData', credit_card.verification_value if credit_card.verification_value
        end
      end
      
      def add_address(xml, options)
        if billing_address = options[:billing_address] || options[:address]
          xml.tag! 'AVS' do
            xml.tag! 'Address', billing_address[:address1]
            xml.tag! 'Zip', billing_address[:zip]
          end
        end
      end
      
      def build_header
        {
          "SOAPAction" => "http://www.mercurypay.com/CreditTransaction",
          "Content-Type" => "text/xml; charset=utf-8"
        }
      end
      
      def parse(action, body)
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
        
        # have to handle batch functions
        xml.elements.each("//BatchSummary/*") do |node|
          response[node.name.underscore.to_sym] = node.text
        end
      end
      
      def endpoint_url
        URLS[test? ? :test : :live]
      end
      
      def commit(action, request)
        response = parse(action, ssl_post(endpoint_url, request, build_header))
        
        success = SUCCESS_CODES.include?(response[:cmd_status])
        message = success ? 'Success' : message_from(response)

        Response.new(success, message, response,
          :test => test?,
          :authorization => response[:auth_code],
          :avs_result => { :code => response[:avs_result] },
          :cvv_result => response[:cvv_result])
      end

      def message_from(response)
        response[:text_response]
      end
      
    end
  end
end

