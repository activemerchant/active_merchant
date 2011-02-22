module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NabTransactGateway < Gateway
      API_VERSION = 'xml-4.2'

      TEST_URL = 'https://transact.nab.com.au/test/xmlapi/payment'
      LIVE_URL = 'https://transact.nab.com.au/live/xmlapi/payment'

      self.supported_countries = ['AU']
      self.homepage_url = 'http://nab.com.au/nabtransact'
      self.display_name = 'NAB Transact'
      self.money_format = :cents
      self.default_currency = 'AUD'

      # The card types supported by the payment gateway
      # Note that support for Diners, Amex, and JCB require extra
      # steps in setting up your account, as detailed in the NAB Transact API
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :diners_club]

      class_inheritable_accessor :request_timeout
      self.request_timeout = 60

      #Transactions currently accepted by NAB Transact XML API
      TRANSACTIONS = {
        :purchase => 0,         #Standard Payment
        :credit => 4,           #Refund
        :void => 6,             #Client Reversal (Void)
        :authorization => 10,   #Preauthorise
        :capture => 11          #Preauthorise Complete (Advice)
      }

      SUCCESS_CODES = [ '00', '08', '11', '16' ]

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def test?
        @options[:test] || super
      end

      def purchase(money, credit_card, options = {})
        commit :purchase, build_purchase_request(money, credit_card, options)
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

      #TODO : Credit Refund Request (available in the API) - (and other services available)

      #Generate payment request XML
      # - API is set to allow multiple Txn's but currentlu only allows one
      # - txnSource = 23 - (XML)
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

      # YYYYDDMMHHNNSSKKK000sOOO
      def generate_timestamp
        time = Time.now.utc
        time.strftime("%Y%d%m%H%M%S#{time.usec}+000")
      end

      def commit(action, request)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, build_request(action, request)))

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

    end
  end
end
