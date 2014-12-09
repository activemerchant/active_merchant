module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The Mercury gateway integration by default requires that the Mercury
    # account being used has tokenization turned. This enables the use of
    # capture/refund/void without having to pass the credit card back in each
    # time. Only the "OneTime" tokenization is used; there is no use of
    # "Recurring" tokenization.
    #
    # If you don't wish to enable Mercury tokenization, you can pass
    # <code>:tokenization => false</code> as an option when creating the
    # gateway. If you do so, then passing a +:credit_card+ option to +capture+
    # and +refund+ will become mandatory.
    class MercuryGateway < Gateway
      URLS = {
        :test => 'https://w1.mercurydev.net/ws/ws.asmx',
        :live => 'https://w1.mercurypay.com/ws/ws.asmx'
      }

      self.homepage_url = 'http://www.mercurypay.com'
      self.display_name = 'Mercury'
      self.supported_countries = ['US','CA']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.default_currency = 'USD'

      STANDARD_ERROR_CODE_MAPPING = {
        '100204' => STANDARD_ERROR_CODE[:invalid_number],
        '100205' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '000000' => STANDARD_ERROR_CODE[:card_declined]
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @use_tokenization = (!options.has_key?(:tokenization) || options[:tokenization])
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

        request = build_non_authorized_request('PreAuth', money, credit_card, options.merge(:authorized => money))
        commit('PreAuth', request)
      end

      def capture(money, authorization, options = {})
        requires!(options, :credit_card) unless @use_tokenization

        request = build_authorized_request('PreAuthCapture', money, authorization, options[:credit_card], options.merge(:authorized => money))
        commit('PreAuthCapture', request)
      end

      def refund(money, authorization, options = {})
        requires!(options, :credit_card) unless @use_tokenization

        request = build_authorized_request('Return', money, authorization, options[:credit_card], options)
        commit('Return', request)
      end

      def void(authorization, options={})
        requires!(options, :credit_card) unless @use_tokenization

        request = build_authorized_request('VoidSale', nil, authorization, options[:credit_card], options)
        commit('VoidSale', request)
      end

      def store(credit_card, options={})
        request = build_card_lookup_request(credit_card, options)
        commit('CardLookup', request)
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
            add_reference(xml, "RecordNumberRequested")
            add_customer_data(xml, options)
            add_amount(xml, money, options)
            add_credit_card(xml, credit_card, action)
            add_address(xml, options) unless credit_card.track_data.present?
          end
        end
        xml = xml.target!
      end

      def build_authorized_request(action, money, authorization, credit_card, options)
        xml = Builder::XmlMarkup.new

        invoice_no, ref_no, auth_code, acq_ref_data, process_data, record_no, amount = split_authorization(authorization)
        ref_no = "1" if ref_no.blank?

        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'Credit'
            if action == 'PreAuthCapture'
              xml.tag! "PartialAuth", "Allow"
            end
            xml.tag! 'TranCode', (@use_tokenization ? (action + "ByRecordNo") : action)
            add_invoice(xml, invoice_no, ref_no, options)
            add_reference(xml, record_no)
            add_customer_data(xml, options)
            add_amount(xml, (money || amount.to_i), options)
            add_credit_card(xml, credit_card, action) if credit_card
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

      def build_card_lookup_request(credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! "TStream" do
          xml.tag! "Transaction" do
            xml.tag! 'TranType', 'CardLookup'
            xml.tag! 'RecordNo', 'RecordNumberRequested'
            xml.tag! 'Frequency', 'OneTime'

            xml.tag! 'Memo', options[:description]
            add_customer_data(xml, options)
            add_credit_card(xml, credit_card, options)
          end
        end
        xml.target!
      end

      def add_invoice(xml, invoice_no, ref_no, options)
        xml.tag! 'InvoiceNo', invoice_no
        xml.tag! 'RefNo', (ref_no || invoice_no)
        xml.tag! 'OperatorID', options[:merchant] if options[:merchant]
        xml.tag! 'Memo', options[:description] if options[:description]
      end

      def add_reference(xml, record_no)
        if @use_tokenization
          xml.tag! "Frequency", "OneTime"
          xml.tag! "RecordNo", record_no
        end
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
          if credit_card.track_data.present?
            xml.tag! 'Track1', credit_card.track_data
          else
            xml.tag! 'AcctNo', credit_card.number
            xml.tag! 'ExpDate', expdate(credit_card)
          end
        end
        xml.tag! 'CardType', CARD_CODES[credit_card.brand] if credit_card.brand

        include_cvv = !%w(Return PreAuthCapture).include?(action) && !credit_card.track_data.present?
        xml.tag! 'CVVData', credit_card.verification_value if(include_cvv && credit_card.verification_value)
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
          :cvv_result => response[:cvv_result],
          :error_code => success ? nil : STANDARD_ERROR_CODE_MAPPING[response[:dsix_return_code]])
      end

      def message_from(response)
        response[:text_response]
      end

      def authorization_from(response)
        dollars, cents = (response[:purchase] || "").split(".").collect{|e| e.to_i}
        dollars ||= 0
        cents ||= 0
        [
          response[:invoice_no],
          response[:ref_no],
          response[:auth_code],
          response[:acq_ref_data],
          response[:process_data],
          response[:record_no],
          ((dollars * 100) + cents).to_s
        ].join(";")
      end

      def split_authorization(authorization)
        invoice_no, ref_no, auth_code, acq_ref_data, process_data, record_no, amount = authorization.split(";")
        [invoice_no, ref_no, auth_code, acq_ref_data, process_data, record_no, amount]
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
