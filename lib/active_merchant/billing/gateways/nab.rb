require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # The National Australia Bank provide a payment gateway that seems to
    # be a rebadged Securepay Australia service.
    #
    # The XML is a tiny bit different though, and I needed support for the
    # periodic API, so I useed the SecurePayAuGateway as a basis for this
    # new class.
    #
    class NabGateway < Gateway
      API_VERSION = 'xml-4.2'
      PERIODIC_API_VERSION = "spxml-4.2"

      TEST_URL = 'https://transact.nab.com.au/test/xmlapi/payment'
      LIVE_URL = 'https://transact.nab.com.au/live/xmlapi/payment'
      TEST_PERIODIC_URL = "https://transact.nab.com.au/xmlapidemo/periodic"
      LIVE_PERIODIC_URL = "https://transact.nab.com.au/xmlapi/periodic"

      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://transact.nab.com.au'

      # The name of the gateway
      self.display_name = 'NAB'

      class_inheritable_accessor :request_timeout
      self.request_timeout = 60

      self.money_format = :cents
      self.default_currency = 'AUD'

      # 0 Standard Payment
      # 4 Refund
      # 6 Client Reversal (Void)
      # 10 Preauthorise
      # 11 Preauth Complete (Advice)
      TRANSACTIONS = {
        :purchase => 0,
        :authorization => 10,
        :capture => 11,
        :void => 6,
        :credit => 4
      }

      PERIODIC_TYPES = {
        :addcrn    => 5,
        :editcrn   => 5,
        :deletecrn => 5,
        :trigger   => 8
      }

      SUCCESS_CODES = [ '00', '08', '11', '16', '77' ]

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def test?
        @options[:test] || super
      end

      def purchase(money, credit_card, options = {})
        if credit_card.is_a?(ActiveMerchant::Billing::CreditCard)
          commit :purchase, build_purchase_request(money, credit_card, options)
        elsif credit_card.to_s.size > 0
          options[:billingid] = credit_card.to_s
          commit_periodic build_periodic_item(:trigger, money, nil, options)
        else
          raise ArgumentError, "credit_card must be a ActiveMerchant::Billing::CreditCard or string with size > 0"
        end
      end

      def store(creditcard, options = {})
        unless options[:billingid].to_s.size > 0
          raise ArgumentError, ":billingid options must be provided"
        end

        commit_periodic(build_periodic_item(:addcrn, 100, creditcard, options))
      end

      def unstore(billingid, options = {})
        if billingid.to_s.size > 0
          options[:billingid] = billingid
        else
          raise ArgumentError, "billingid must be provided"
        end

        commit_periodic(build_periodic_item(:deletecrn, 100, nil, options))
      end

      private

      def build_purchase_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'amount', amount(money)
        xml.tag! 'currency', options[:currency] || currency(money)
        xml.tag! 'purchaseOrderNo', options[:order_id].to_s.gsub(/[ ']/, '')

        xml.tag! 'CreditCardInfo' do
          xml.tag! 'cardNumber', credit_card.number
          xml.tag! 'expiryDate', expdate(credit_card)
          xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
        end

        xml.target!
      end

      def build_request(action, body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'NABTransactMessage' do
          xml.tag! 'MessageInfo' do
            xml.tag! 'messageID', Utils.generate_unique_id.slice(0, 30)
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
            xml.tag! 'TxnList', "count" => 1 do
              xml.tag! 'Txn', "ID" => 1 do
                xml.tag! 'txnType', TRANSACTIONS[action]
                xml.tag! 'txnSource', 23
                xml << body
              end
            end
          end
        end

        xml.target!
      end

      def build_periodic_item(action, money, credit_card, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'actionType', action.to_s
        xml.tag! 'periodicType', PERIODIC_TYPES[action] if PERIODIC_TYPES[action]
        xml.tag! 'crn', options[:billingid].to_s

        if credit_card
          xml.tag! 'CreditCardInfo' do
            xml.tag! 'cardNumber', credit_card.number
            xml.tag! 'expiryDate', expdate(credit_card)
            xml.tag! 'cvv', credit_card.verification_value if credit_card.verification_value?
          end
        end
        xml.tag! 'amount', amount(money)

        xml.target!
      end

      def build_periodic_request(body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'NABTransactMessage' do
          xml.tag! 'MessageInfo' do
            xml.tag! 'messageID', ActiveMerchant::Utils.generate_unique_id.slice(0, 30)
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
            xml.tag! 'PeriodicList', "count" => 1 do
              xml.tag! 'PeriodicItem', "ID" => 1 do
                xml << body
              end
            end
          end
        end

        xml.target!
      end

      def commit(action, request)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, build_request(action, request)))

        Response.new(success?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response)
        )
      end

      def commit_periodic(request)
        response = parse(ssl_post(test? ? TEST_PERIODIC_URL : LIVE_PERIODIC_URL, build_periodic_request(request)))

        Response.new(success?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response)
        )
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:response_code])
      end

      def authorization_from(response)
        response[:txn_id]
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
          node.elements.each{|element| parse_element(response, element) }
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

