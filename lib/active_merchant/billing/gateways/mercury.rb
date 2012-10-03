module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercuryGateway < Gateway
      URLS = {
        :test => 'https://w1.mercurydev.net/ws/ws.asmx',
        :live => 'https://w1.mercurypay.com/ws/ws.asmx'
      }

      self.homepage_url = 'http://www.mercurypay.com'
      self.display_name = 'Mercury'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.default_currency = 'USD'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)

        request = build_non_authorized_request('Sale', money, credit_card, options)
        commit('Sale', request)
      end

      def credit(money, credit_card, options = {})
        requires!(options, :order_id)

        request = build_non_authorized_request('Return', money, credit_card, options)
        commit('Return', request)
      end

      def authorize(money, credit_card, options = {})
        requires!(options, :order_id)

        options[:authorized] ||= money
        request = build_non_authorized_request('PreAuth', money, credit_card, options)
        commit('PreAuth', request)
      end

      def capture(money, authorization, options = {})
        requires!(options, :credit_card)
        options[:authorized] ||= money
        request = build_authorized_request('PreAuthCapture', money, authorization, options[:credit_card], options)
        commit('PreAuthCapture', request)
      end

      def refund(money, authorization, options = {})
        requires!(options, :credit_card)

        request = build_authorized_request('VoidSale', money, authorization, options[:credit_card], options)
        commit(options[:void], request)
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      private

      def build_non_authorized_request(action, money, credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'Credit'
            xml.tag! 'TranCode', action
            if action == 'PreAuth' || action == 'Sale'
              xml.tag! "PartialAuth", "Allow"
            end
            add_invoice(xml, options[:order_id], nil, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card, action)
            add_address(xml, options)
          end
        end
        xml = xml.target!
      end

      def build_authorized_request(action, money, authorization, credit_card, options)
        xml = Builder::XmlMarkup.new

        invoice_no, ref_no, auth_code, acq_ref_data, process_data = split_authorization(authorization)

        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'Credit'
            xml.tag! 'TranCode', action
            if action == 'PreAuthCapture'
              xml.tag! "PartialAuth", "Allow"
            end
            add_invoice(xml, invoice_no, ref_no, options)
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card, action)
            add_address(xml, options)
            xml.tag! 'TranInfo' do
              xml.tag! "AuthCode", auth_code
              xml.tag! "AcqRefData", acq_ref_data
              xml.tag! "ProcessData", process_data
            end
          end
        end
        xml = xml.target!
      end

      def add_invoice(xml, invoice_no, ref_no, options)
        if /^\d+$/ !~ invoice_no.to_s
          raise ArgumentError.new("#{invoice_no} is not numeric as required by Mercury")
        end

        xml.tag! 'InvoiceNo', invoice_no
        xml.tag! 'RefNo', ref_no || invoice_no
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

      CARD_CODES = {
        'visa' => 'VISA',
        'master' => 'M/C',
        'american_express' => 'AMEX',
        'discover' => 'DCVR',
        'diners_club' => 'DCLB',
        'jcb' => 'JCB'
      }

      def add_credit_card(xml, credit_card, action)
        xml.tag! 'Account' do
          xml.tag! 'AcctNo', credit_card.number
          xml.tag! 'ExpDate', expdate(credit_card)
        end
        xml.tag! 'CardType', CARD_CODES[credit_card.brand] if credit_card.brand

        include_cvv = !%w(Return PreAuthCapture).include?(action)
        xml.tag! 'CVVData', credit_card.verification_value if(include_cvv && credit_card.verification_value)
      end

      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

      def add_address(xml, options)
        if billing_address = options[:billing_address] || options[:address]
          xml.tag! 'AVS' do
            xml.tag! 'Address', billing_address[:address1]
            xml.tag! 'Zip', billing_address[:zip]
          end
        end
      end

      def parse(action, body)
        response = {}
        hashify_xml!(unescape_xml(body), response)
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

      def build_soap_request(body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! 'soap:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'soap:Body' do
            xml.tag! 'CreditTransaction', 'xmlns' => homepage_url do
              xml.tag! 'tran' do
                xml << escape_xml(body)
              end
              xml.tag! 'pw', @options[:password]
            end
          end
        end
        xml.target!
      end

      def build_header
        {
          "SOAPAction" => "http://www.mercurypay.com/CreditTransaction",
          "Content-Type" => "text/xml; charset=utf-8"
        }
      end

      SUCCESS_CODES = [ 'Approved', 'Success' ]

      def commit(action, request)
        response = parse(action, ssl_post(endpoint_url, build_soap_request(request), build_header))

        success = SUCCESS_CODES.include?(response[:cmd_status])
        message = success ? 'Success' : message_from(response)

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => response[:avs_result] },
          :cvv_result => response[:cvv_result])
      end

      def message_from(response)
        response[:text_response]
      end

      def authorization_from(response)
        [
          response[:invoice_no],
          response[:ref_no],
          response[:auth_code],
          response[:acq_ref_data],
          response[:process_data]
        ].join(";")
      end

      def split_authorization(authorization)
        invoice_no, ref_no, auth_code, acq_ref_data, process_data = authorization.split(";")
        [invoice_no, ref_no, auth_code, acq_ref_data, process_data]
      end

      ENVELOPE_NAMESPACES = {
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:soap' => "http://schemas.xmlsoap.org/soap/envelope/",
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      }

      def escape_xml(xml)
        "\n<![CDATA[\n#{xml}\n]]>\n"
      end

      def unescape_xml(escaped_xml)
        escaped_xml.gsub(/\&gt;/,'>').gsub(/\&lt;/,'<')
      end
    end
  end
end
