require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The National Australia Bank provide a payment gateway that seems to
    # be a rebadged Securepay Australia service, though some differences exist.
    class NabTransactGateway < Gateway
      API_VERSION = 'xml-4.2'
      PERIODIC_API_VERSION = 'spxml-4.2'

      class_attribute :test_periodic_url, :live_periodic_url

      self.test_url = 'https://demo.transact.nab.com.au/xmlapi/payment'
      self.live_url = 'https://transact.nab.com.au/live/xmlapi/payment'
      self.test_periodic_url = 'https://demo.transact.nab.com.au/xmlapi/periodic'
      self.live_periodic_url = 'https://transact.nab.com.au/xmlapi/periodic'

      self.supported_countries = ['AU']
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]

      self.homepage_url = 'http://transact.nab.com.au'
      self.display_name = 'NAB Transact'
      self.money_format = :cents
      self.default_currency = 'AUD'

      # Transactions currently accepted by NAB Transact XML API
      TRANSACTIONS = {
        purchase: 0,           # Standard Payment
        refund: 4,             # Refund
        void: 6,               # Client Reversal (Void)
        unmatched_refund: 666, # Unmatched Refund
        authorization: 10,     # Preauthorise
        capture: 11            # Preauthorise Complete (Advice)
      }

      PERIODIC_TYPES = {
        addcrn: 5,
        deletecrn: 5,
        trigger: 8
      }

      SUCCESS_CODES = %w[00 08 11 16 77]

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, credit_card_or_stored_id, options = {})
        if credit_card_or_stored_id.respond_to?(:number)
          commit :purchase, build_purchase_request(money, credit_card_or_stored_id, options)
        else
          commit_periodic(:trigger, build_purchase_using_stored_card_request(money, credit_card_or_stored_id, options))
        end
      end

      def credit(money, credit_card, options = {})
        commit :unmatched_refund, build_purchase_request(money, credit_card, options)
      end

      def refund(money, authorization, options = {})
        commit :refund, build_reference_request(money, authorization, options)
      end

      def authorize(money, credit_card, options = {})
        commit :authorization, build_purchase_request(money, credit_card, options)
      end

      def capture(money, authorization, options = {})
        commit :capture, build_reference_request(money, authorization, options)
      end

      def store(credit_card, options = {})
        commit_periodic(:addcrn, build_store_request(credit_card, options))
      end

      def unstore(identification, options = {})
        commit_periodic(:deletecrn, build_unstore_request(identification, options))
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        return '' if transcript.blank?

        transcript.
          gsub(%r((<cardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<cvv>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      def add_metadata(xml, options)
        if options[:merchant_name] || options[:merchant_location]
          xml.tag! 'metadata' do
            xml.tag! 'meta', name: 'ca_name', value: options[:merchant_name] if options[:merchant_name]
            xml.tag! 'meta', name: 'ca_location', value: options[:merchant_location] if options[:merchant_location]
          end
        end
      end

      def build_purchase_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new
        xml.tag! 'amount', localized_amount(money, options[:currency] || currency(money))
        xml.tag! 'currency', options[:currency] || currency(money)
        xml.tag! 'purchaseOrderNo', options[:order_id].to_s.gsub(/[ ']/, '')

        xml.tag! 'CreditCardInfo' do
          xml.tag! 'cardNumber', credit_card.number
          xml.tag! 'expiryDate', expdate(credit_card)
          xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
        end

        add_metadata(xml, options)

        xml.target!
      end

      def build_reference_request(money, reference, options)
        xml = Builder::XmlMarkup.new

        transaction_id, order_id, preauth_id, original_amount = reference.split('*')

        xml.tag! 'amount', (money ? localized_amount(money, options[:currency] || currency(money)) : original_amount)
        xml.tag! 'currency', options[:currency] || currency(money)
        xml.tag! 'txnID', transaction_id
        xml.tag! 'purchaseOrderNo', order_id
        xml.tag! 'preauthID', preauth_id

        add_metadata(xml, options)

        xml.target!
      end

      # Generate payment request XML
      # - API is set to allow multiple Txn's but currently only allows one
      # - txnSource = 23 - (XML)
      def build_request(action, body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'NABTransactMessage' do
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

      def build_periodic_request(action, body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'NABTransactMessage' do
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
                xml.tag! 'actionType', action.to_s
                xml.tag! 'periodicType', PERIODIC_TYPES[action] if PERIODIC_TYPES[action]
                xml << body
              end
            end
          end
        end

        xml.target!
      end

      def build_purchase_using_stored_card_request(money, identification, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'crn', identification
        xml.tag! 'currency', options[:currency] || currency(money)
        xml.tag! 'amount', localized_amount(money, options[:currency] || currency(money))

        xml.target!
      end

      def build_store_request(credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'crn', options[:billing_id] || SecureRandom.hex(10)
        xml.tag! 'CreditCardInfo' do
          xml.tag! 'cardNumber', credit_card.number
          xml.tag! 'expiryDate', expdate(credit_card)
          xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
        end

        xml.target!
      end

      def build_unstore_request(identification, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'crn', identification
        xml.target!
      end

      def commit(action, request)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, build_request(action, request)))

        Response.new(success?(response), message_from(response), response,
          test: test?,
          authorization: authorization_from(action, response)
        )
      end

      def commit_periodic(action, request)
        response = parse(ssl_post(test? ? self.test_periodic_url : self.live_periodic_url, build_periodic_request(action, request)))
        Response.new(success?(response), message_from(response), response,
          test: test?,
          authorization: authorization_from(action, response)
        )
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:response_code])
      end

      def authorization_from(action, response)
        if action == :addcrn
          response[:crn]
        else
          [response[:txn_id], response[:purchase_order_no], response[:preauth_id], response[:amount]].join('*')
        end
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

      def request_timeout
        @options[:request_timeout] || 60
      end
    end
  end
end
