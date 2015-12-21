module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecureNetGateway < Gateway

      API_VERSION = "4.0"

      TRANSACTIONS = {
        :auth_only                      => "0000",
        :auth_capture                   => "0100",
        :prior_auth_capture             => "0200",
        :void                           => "0400",
        :credit                         => "0500"
      }

      XML_ATTRIBUTES = {
                        'xmlns' => "http://gateway.securenet.com/API/Contracts",
                        'xmlns:i' => "http://www.w3.org/2001/XMLSchema-instance"
                       }
      NIL_ATTRIBUTE = { 'i:nil' => "true" }

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.securenet.com/'
      self.display_name = 'SecureNet'

      self.test_url = 'https://certify.securenet.com/API/gateway.svc/webHttp/ProcessTransaction'
      self.live_url = 'https://gateway.securenet.com/api/Gateway.svc/webHttp/ProcessTransaction'

      APPROVED, DECLINED = 1, 2

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        commit(build_sale_or_authorization(creditcard, options, :auth_only, money))
      end

      def purchase(money, creditcard, options = {})
        commit(build_sale_or_authorization(creditcard, options, :auth_capture, money))
      end

      def capture(money, authorization, options = {})
        commit(build_capture_refund_void(authorization, options, :prior_auth_capture, money))
      end

      def void(authorization, options = {})
        commit(build_capture_refund_void(authorization, options, :void))
      end

      def refund(money, authorization, options = {})
        commit(build_capture_refund_void(authorization, options, :credit, money))
      end

      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end


      private
      def commit(request)
        xml = build_request(request)
        url = test? ? self.test_url : self.live_url
        data = ssl_post(url, xml, "Content-Type" => "text/xml")
        response = parse(data)

        Response.new(success?(response), message_from(response), response,
          :test => test?,
          :authorization => build_authorization(response),
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code_response_code]
        )
      end

      def build_request(request)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag!("TRANSACTION", XML_ATTRIBUTES) do
          xml << request
        end

        xml.target!
      end

      def build_sale_or_authorization(creditcard, options, action, money)
        xml = Builder::XmlMarkup.new

        xml.tag! 'AMOUNT', amount(money)
        add_credit_card(xml, creditcard)
        add_params_in_required_order(xml, action, creditcard, options)
        add_more_required_params(xml, options)

        xml.target!
      end

      def build_capture_refund_void(authorization, options, action, money = nil)
        xml = Builder::XmlMarkup.new

        transaction_id, amount_in_ref, last_four = split_authorization(authorization)

        xml.tag! 'AMOUNT', amount(money) || amount_in_ref
        xml.tag!("CARD") do
          xml.tag! 'CARDNUMBER', last_four
        end

        add_params_in_required_order(xml, action, nil, options)
        xml.tag! 'REF_TRANSID', transaction_id
        add_more_required_params(xml, options)

        xml.target!
      end

      def add_credit_card(xml, creditcard)
        xml.tag!("CARD") do
          xml.tag! 'CARDCODE', creditcard.verification_value if creditcard.verification_value?
          xml.tag! 'CARDNUMBER', creditcard.number
          xml.tag! 'EXPDATE', expdate(creditcard)
        end
      end

      def add_customer_data(xml, options)
        if options.has_key? :customer
          xml.tag! 'CUSTOMERID', options[:customer]
        end

        if options.has_key? :ip
          xml.tag! 'CUSTOMERIP', options[:ip]
        end
      end

      def add_address(xml, creditcard, options)
        return unless creditcard

        if address = options[:billing_address] || options[:address]
          xml.tag!("CUSTOMER_BILL") do
            xml.tag! 'ADDRESS', address[:address1].to_s
            xml.tag! 'CITY', address[:city].to_s
            xml.tag! 'COMPANY', address[:company].to_s
            xml.tag! 'COUNTRY', address[:country].to_s
            if options.has_key? :email
              xml.tag! 'EMAIL', options[:email]
              xml.tag! 'EMAILRECEIPT', 'FALSE'
            end
            xml.tag! 'FIRSTNAME', creditcard.first_name
            xml.tag! 'LASTNAME', creditcard.last_name
            xml.tag! 'PHONE', address[:phone].to_s
            xml.tag! 'STATE', address[:state].blank?  ? 'n/a' : address[:state]
            xml.tag! 'ZIP', address[:zip].to_s
          end
        end

        if address = options[:shipping_address]
          xml.tag!("CUSTOMER_SHIP") do
            xml.tag! 'ADDRESS', address[:address1].to_s
            xml.tag! 'CITY', address[:city].to_s
            xml.tag! 'COMPANY', address[:company].to_s
            xml.tag! 'COUNTRY', address[:country].to_s

            if address[:name]
              first_name, last_name = split_names(address[:name])
              xml.tag! 'FIRSTNAME', first_name
              xml.tag! 'LASTNAME', last_name
            else
              xml.tag! 'FIRSTNAME', address[:first_name].to_s
              xml.tag! 'LASTNAME', address[:last_name].to_s
            end

            xml.tag! 'STATE', address[:state].blank?  ? 'n/a' : address[:state]
            xml.tag! 'ZIP', address[:zip].to_s
          end
        else
          xml.tag!('CUSTOMER_SHIP', NIL_ATTRIBUTE) do
          end
        end

      end

      def add_merchant_key(xml, options)
        xml.tag!("MERCHANT_KEY") do
          xml.tag! 'GROUPID', 0
          xml.tag! 'SECUREKEY', @options[:password]
          xml.tag! 'SECURENETID', @options[:login]
        end
      end

      # SecureNet requires some of the xml params to be in a certain order.  http://cl.ly/image/3K260E0p0a0n/content.png
      def add_params_in_required_order(xml, action, creditcard, options)
        xml.tag! 'CODE', TRANSACTIONS[action]
        add_customer_data(xml, options)
        add_address(xml, creditcard, options)
        xml.tag! 'DCI', 0 # No duplicate checking will be done, except for ORDERID
        xml.tag! 'INSTALLMENT_SEQUENCENUM', 1
        xml.tag! 'INVOICEDESC', options[:invoice_description] if options[:invoice_description]
        xml.tag! 'INVOICENUM', options[:invoice_number] if options[:invoice_number]
        add_merchant_key(xml, options)
        xml.tag! 'METHOD', 'CC'
        xml.tag! 'NOTE', options[:description] if options[:description]
        xml.tag! 'ORDERID', truncate(options[:order_id], 25)
        xml.tag! 'OVERRIDE_FROM', 0 # Docs say not required, but doesn't work without it
      end

      def add_more_required_params(xml, options)
        test_mode = options[:test_mode].nil? ? test? : options[:test_mode]
        xml.tag! 'RETAIL_LANENUM', '0'
        xml.tag! 'TEST', test_mode ? 'TRUE' : 'FALSE'
        xml.tag! 'TOTAL_INSTALLMENTCOUNT', 0
        xml.tag! 'TRANSACTION_SERVICE', 0
        xml.tag! 'DEVELOPERID', options[:developer_id] if options[:developer_id]
      end

      def success?(response)
        response[:response_code].to_i == APPROVED
      end

      def message_from(response)
        if response[:response_code].to_i == DECLINED
          return CVVResult.messages[ response[:card_code_response_code] ] if CARD_CODE_ERRORS.include?(response[:card_code_response_code])
          return AVSResult.messages[ response[:avs_result_code] ] if AVS_ERRORS.include?(response[:avs_result_code])
        end

        return response[:response_reason_text].nil? ? '' : response[:response_reason_text][0..-1]
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)
        root = REXML::XPath.first(xml, "//GATEWAYRESPONSE")
        if root
          root.elements.to_a.each do |node|
            recurring_parse_element(response, node)
          end
        end

        response
      end

      def recurring_parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def split_authorization(authorization)
        transaction_id, amount, last_four = authorization.split("|")
        [transaction_id, amount, last_four]
      end

      def build_authorization(response)
        [response[:transactionid], response[:transactionamount], response[:last4_digits]].join("|")
      end

    end
  end
end

