require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayAuGateway < Gateway
      API_VERSION = 'xml-4.2'
      PERIODIC_API_VERSION = 'spxml-3.0'

      class_attribute :test_periodic_url, :live_periodic_url

      self.test_url = 'https://test.api.securepay.com.au/xmlapi/payment'
      self.live_url = 'https://api.securepay.com.au/xmlapi/payment'

      self.test_periodic_url = 'https://test.securepay.com.au/xmlapi/periodic'
      self.live_periodic_url = 'https://api.securepay.com.au/xmlapi/periodic'

      self.supported_countries = ['AU']
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://securepay.com.au'

      # The name of the gateway
      self.display_name = 'SecurePay'

      class_attribute :request_timeout
      self.request_timeout = 60

      self.money_format = :cents
      self.default_currency = 'AUD'

      # 0 Standard Payment
      # 4 Refund
      # 6 Client Reversal (Void)
      # 10 Preauthorise
      # 11 Preauth Complete (Advice)
      TRANSACTIONS = {
        purchase:       0,
        authorization:  10,
        capture:        11,
        void:           6,
        refund:         4
      }

      PERIODIC_ACTIONS = {
        add_triggered:      'add',
        remove_triggered:   'delete',
        trigger:            'trigger'
      }

      PERIODIC_TYPES = {
        add_triggered:    4,
        remove_triggered: nil,
        trigger:          nil
      }

      SUCCESS_CODES = %w[00 08 11 16 77]

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, credit_card_or_stored_id, options = {})
        if credit_card_or_stored_id.respond_to?(:number)
          requires!(options, :order_id)
          commit :purchase, build_purchase_request(money, credit_card_or_stored_id, options)
        else
          options[:billing_id] = credit_card_or_stored_id.to_s
          commit_periodic(build_periodic_item(:trigger, money, nil, options))
        end
      end

      def authorize(money, credit_card, options = {})
        requires!(options, :order_id)
        commit :authorization, build_purchase_request(money, credit_card, options)
      end

      def capture(money, reference, options = {})
        commit :capture, build_reference_request(money, reference)
      end

      def refund(money, reference, options = {})
        commit :refund, build_reference_request(money, reference)
      end

      def credit(money, reference, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, reference)
      end

      def void(reference, options = {})
        commit :void, build_reference_request(nil, reference)
      end

      def store(creditcard, options = {})
        requires!(options, :billing_id, :amount)
        commit_periodic(build_periodic_item(:add_triggered, options[:amount], creditcard, options))
      end

      def unstore(identification, options = {})
        options[:billing_id] = identification
        commit_periodic(build_periodic_item(:remove_triggered, options[:amount], nil, options))
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<merchantID>).+(</merchantID>)), '\1[FILTERED]\2').
          gsub(%r((<password>).+(</password>)), '\1[FILTERED]\2').
          gsub(%r((<cardNumber>).+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cvv>).+(</cvv>)), '\1[FILTERED]\2')
      end

      private

      def build_purchase_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new

        currency = options[:currency] || currency(money)

        xml.tag! 'amount', localized_amount(money, currency)
        xml.tag! 'currency', currency
        xml.tag! 'purchaseOrderNo', options[:order_id].to_s.gsub(/[ ']/, '')

        xml.tag! 'CreditCardInfo' do
          xml.tag! 'cardNumber', credit_card.number
          xml.tag! 'expiryDate', expdate(credit_card)
          xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
        end

        xml.target!
      end

      def build_reference_request(money, reference)
        xml = Builder::XmlMarkup.new

        transaction_id, order_id, preauth_id, original_amount = reference.split('*')

        xml.tag! 'amount', (money ? amount(money) : original_amount)
        xml.tag! 'currency', options[:currency] || currency(money)
        xml.tag! 'txnID', transaction_id
        xml.tag! 'purchaseOrderNo', order_id
        xml.tag! 'preauthID', preauth_id

        xml.target!
      end

      def build_request(action, body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'SecurePayMessage' do
          xml.tag! 'MessageInfo' do
            xml.tag! 'messageID', SecureRandom.hex(15)
            xml.tag! 'messageTimestamp', generate_timestamp
            xml.tag! 'timeoutValue', request_timeout
            xml.tag! 'apiVersion', API_VERSION
          end

          xml.tag! 'MerchantInfo' do
            xml.tag! 'merchantID', @options[:login]
            xml.tag! 'password', @options[:password]
          end

          xml.tag! 'RequestType', 'Payment'
          xml.tag! 'Payment' do
            xml.tag! 'TxnList', 'count' => 1 do
              xml.tag! 'Txn', 'ID' => 1 do
                xml.tag! 'txnType', TRANSACTIONS[action]
                xml.tag! 'txnSource', 23
                xml << body
              end
            end
          end
        end

        xml.target!
      end

      def commit(action, request)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, build_request(action, request)))

        Response.new(success?(response), message_from(response), response,
          test: test?,
          authorization: authorization_from(response)
        )
      end

      def build_periodic_item(action, money, credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'actionType', PERIODIC_ACTIONS[action]
        xml.tag! 'clientID', options[:billing_id].to_s

        if credit_card
          xml.tag! 'CreditCardInfo' do
            xml.tag! 'cardNumber', credit_card.number
            xml.tag! 'expiryDate', expdate(credit_card)
            xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
          end
        end
        xml.tag! 'amount', amount(money)
        xml.tag! 'periodicType', PERIODIC_TYPES[action] if PERIODIC_TYPES[action]

        xml.target!
      end

      def build_periodic_request(body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'SecurePayMessage' do
          xml.tag! 'MessageInfo' do
            xml.tag! 'messageID', SecureRandom.hex(15)
            xml.tag! 'messageTimestamp', generate_timestamp
            xml.tag! 'timeoutValue', request_timeout
            xml.tag! 'apiVersion', PERIODIC_API_VERSION
          end

          xml.tag! 'MerchantInfo' do
            xml.tag! 'merchantID', @options[:login]
            xml.tag! 'password', @options[:password]
          end

          xml.tag! 'RequestType', 'Periodic'
          xml.tag! 'Periodic' do
            xml.tag! 'PeriodicList', 'count' => 1 do
              xml.tag! 'PeriodicItem', 'ID' => 1 do
                xml << body
              end
            end
          end
        end
        xml.target!
      end

      def commit_periodic(request)
        my_request = build_periodic_request(request)
        response = parse(ssl_post(test? ? self.test_periodic_url : self.live_periodic_url, my_request))

        Response.new(success?(response), message_from(response), response,
          test: test?,
          authorization: authorization_from(response)
        )
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:response_code])
      end

      def authorization_from(response)
        [response[:txn_id], response[:purchase_order_no], response[:preauth_id], response[:amount]].join('*')
      end

      def message_from(response)
        response[:response_text] || response[:status_description]
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}/#{format(credit_card.year, :two_digits)}"
      end

      def parse(body)
        xml = REXML::Document.new(body)

        response = {}

        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end

        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each { |element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      # YYYYDDMMHHNNSSKKK000sOOO
      def generate_timestamp
        time = Time.now.utc
        time.strftime("%Y%d%m%H%M%S#{time.usec}+000")
      end
    end
  end
end
