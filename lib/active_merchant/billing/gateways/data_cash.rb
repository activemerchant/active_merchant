require 'active_support/core_ext/string/access'

module ActiveMerchant
  module Billing
    class DataCashGateway < Gateway
      self.default_currency = 'GBP'
      self.supported_countries = ['GB']

      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb maestro]

      self.homepage_url = 'http://www.datacash.com/'
      self.display_name = 'DataCash'

      self.test_url = 'https://testserver.datacash.com/Transaction'
      self.live_url = 'https://mars.transaction.datacash.com/Transaction'

      AUTH_TYPE = 'auth'
      CANCEL_TYPE = 'cancel'
      FULFILL_TYPE = 'fulfill'
      PRE_TYPE = 'pre'
      REFUND_TYPE = 'refund'
      TRANSACTION_REFUND_TYPE = 'txn_refund'

      POLICY_ACCEPT = 'accept'
      POLICY_REJECT = 'reject'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, authorization_or_credit_card, options = {})
        requires!(options, :order_id)

        if authorization_or_credit_card.is_a?(String)
          request = build_purchase_or_authorization_request_with_continuous_authority_reference_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        else
          request = build_purchase_or_authorization_request_with_credit_card_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        end

        commit(request)
      end

      def authorize(money, authorization_or_credit_card, options = {})
        requires!(options, :order_id)

        if authorization_or_credit_card.is_a?(String)
          request = build_purchase_or_authorization_request_with_continuous_authority_reference_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        else
          request = build_purchase_or_authorization_request_with_credit_card_request(PRE_TYPE, money, authorization_or_credit_card, options)
        end

        commit(request)
      end

      def capture(money, authorization, options = {})
        commit(build_void_or_capture_request(FULFILL_TYPE, money, authorization, options))
      end

      def void(authorization, options = {})
        request = build_void_or_capture_request(CANCEL_TYPE, nil, authorization, options)

        commit(request)
      end

      def credit(money, reference_or_credit_card, options = {})
        if reference_or_credit_card.is_a?(String)
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
          refund(money, reference_or_credit_card)
        else
          request = build_credit_request(money, reference_or_credit_card, options)
          commit(request)
        end
      end

      def refund(money, reference, options = {})
        commit(build_transaction_refund_request(money, reference))
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(<pan>)\d+(<\/pan>)/i, '\1[FILTERED]\2').
          gsub(/(<cv2>)\d+(<\/cv2>)/i, '\1[FILTERED]\2').
          gsub(/(<password>).+(<\/password>)/i, '\1[FILTERED]\2')
      end

      private

      def build_void_or_capture_request(type, money, authorization, options)
        parsed_authorization = parse_authorization_string(authorization)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! :Request, version: '2' do
          add_authentication(xml)

          xml.tag! :Transaction do
            xml.tag! :HistoricTxn do
              xml.tag! :reference, parsed_authorization[:reference]
              xml.tag! :authcode, parsed_authorization[:auth_code]
              xml.tag! :method, type
            end

            if money
              xml.tag! :TxnDetails do
                xml.tag! :merchantreference, format_reference_number(options[:order_id])
                xml.tag! :amount, amount(money), currency: options[:currency] || currency(money)
                xml.tag! :capturemethod, 'ecomm'
              end
            end
          end
        end
        xml.target!
      end

      def build_purchase_or_authorization_request_with_credit_card_request(type, money, credit_card, options)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! :Request, version: '2' do
          add_authentication(xml)

          xml.tag! :Transaction do
            xml.tag! :ContAuthTxn, type: 'setup' if options[:set_up_continuous_authority]
            xml.tag! :CardTxn do
              xml.tag! :method, type
              add_credit_card(xml, credit_card, options[:billing_address])
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money), currency: options[:currency] || currency(money)
              xml.tag! :capturemethod, 'ecomm'
            end
          end
        end
        xml.target!
      end

      def build_purchase_or_authorization_request_with_continuous_authority_reference_request(type, money, authorization, options)
        parsed_authorization = parse_authorization_string(authorization)
        raise ArgumentError, 'The continuous authority reference is required for continuous authority transactions' if parsed_authorization[:ca_reference].blank?

        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! :Request, version: '2' do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :ContAuthTxn, type: 'historic'
            xml.tag! :HistoricTxn do
              xml.tag! :reference, parsed_authorization[:ca_reference]
              xml.tag! :method, type
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money), currency: options[:currency] || currency(money)
              xml.tag! :capturemethod, 'cont_auth'
            end
          end
        end
        xml.target!
      end

      def build_transaction_refund_request(money, authorization)
        parsed_authorization = parse_authorization_string(authorization)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! :Request, version: '2' do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :HistoricTxn do
              xml.tag! :reference, parsed_authorization[:reference]
              xml.tag! :method, TRANSACTION_REFUND_TYPE
            end
            unless money.nil?
              xml.tag! :TxnDetails do
                xml.tag! :amount, amount(money)
                xml.tag! :capturemethod, 'ecomm'
              end
            end
          end
        end
        xml.target!
      end

      def build_credit_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! :Request, version: '2' do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :CardTxn do
              xml.tag! :method, REFUND_TYPE
              add_credit_card(xml, credit_card, options[:billing_address])
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money)
              xml.tag! :capturemethod, 'ecomm'
            end
          end
        end
        xml.target!
      end

      def add_authentication(xml)
        xml.tag! :Authentication do
          xml.tag! :client, @options[:login]
          xml.tag! :password, @options[:password]
        end
      end

      def add_credit_card(xml, credit_card, address)
        xml.tag! :Card do
          # DataCash calls the CC number 'pan'
          xml.tag! :pan, credit_card.number
          xml.tag! :expirydate, format_date(credit_card.month, credit_card.year)

          xml.tag! :Cv2Avs do
            xml.tag! :cv2, credit_card.verification_value if credit_card.verification_value?
            if address
              xml.tag! :street_address1, address[:address1] unless address[:address1].blank?
              xml.tag! :street_address2, address[:address2] unless address[:address2].blank?
              xml.tag! :street_address3, address[:address3] unless address[:address3].blank?
              xml.tag! :street_address4, address[:address4] unless address[:address4].blank?
              xml.tag! :postcode, address[:zip] unless address[:zip].blank?
            end

            # The ExtendedPolicy defines what to do when the passed data
            # matches, or not...
            #
            # All of the following elements MUST be present for the
            # xml to be valid (or can drop the ExtendedPolicy and use
            # a predefined one
            xml.tag! :ExtendedPolicy do
              xml.tag! :cv2_policy,
                notprovided: POLICY_REJECT,
                notchecked: POLICY_REJECT,
                matched: POLICY_ACCEPT,
                notmatched: POLICY_REJECT,
                partialmatch: POLICY_REJECT
              xml.tag! :postcode_policy,
                notprovided: POLICY_ACCEPT,
                notchecked: POLICY_ACCEPT,
                matched: POLICY_ACCEPT,
                notmatched: POLICY_REJECT,
                partialmatch: POLICY_ACCEPT
              xml.tag! :address_policy,
                notprovided: POLICY_ACCEPT,
                notchecked: POLICY_ACCEPT,
                matched: POLICY_ACCEPT,
                notmatched: POLICY_REJECT,
                partialmatch: POLICY_ACCEPT
            end
          end
        end
      end

      def commit(request)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, request))

        Response.new(response[:status] == '1', response[:reason], response,
          test: test?,
          authorization: "#{response[:datacash_reference]};#{response[:authcode]};#{response[:ca_reference]}"
        )
      end

      def format_date(month, year)
        "#{format(month, :two_digits)}/#{format(year, :two_digits)}"
      end

      def parse(body)
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, '//Response')

        root.elements.to_a.each do |node|
          parse_element(response, node)
        end

        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each { |e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def format_reference_number(number)
        number.to_s.gsub(/[^A-Za-z0-9]/, '').rjust(6, '0').first(30)
      end

      def parse_authorization_string(authorization)
        reference, auth_code, ca_reference = authorization.to_s.split(';')
        {reference: reference, auth_code: auth_code, ca_reference: ca_reference}
      end
    end
  end
end
