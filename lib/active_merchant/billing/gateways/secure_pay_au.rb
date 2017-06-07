require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module supports the SecurePay (Australia) gateway www.securepay.com.au.  For more information on the
    # SecurePayAu Gateway please see their {Integration Guides}[https://www.securepay.com.au/developers/integration-guides].
    #
    # == FraudGuard
    #
    # FraudGuard sends extra information to SecurePayAu for Fraud Detection.  It is a rule/score based system that can be customized
    # through the web interface to weight information such as countries, source card countries, IP geo-located country, etc.
    #
    # Common usage is to limit payments to cards from a certain country, or to ensure the card country matches the delivery address, etc.
    #
    # For more information on FraudGuard, see the {FraudGuard Product Guide}[https://www.securepay.com.au//developers/products-and-services/fraudguard/]
    #
    # Requirements for FraudGuard
    # 1. Ensure the service is activated and appropriately setup in your account
    # 2. Can only be used with a standard payment, not supported when storing or using stored cards.
    # 3. Enable the Fraud check by passing {:fraud => true} in either the global options during initialization, or to the options hash of #purchase
    # 4. Pass the following information to #purchase, or #antifraud_request inside the options hash
    #    - Required: options[:ip]
    #    - Optional: options[:email], options[:billing_address], options[:shipping_address], options[:address]
    #
    # Note: You can optionally set {:fraud => true} in the global options instead, if you later set one in #purchase it will override the global setting.
    class SecurePayAuGateway < Gateway

      API_VERSION = 'xml-4.2'
      PERIODIC_API_VERSION = 'spxml-3.0'

      class_attribute :test_periodic_url, :live_periodic_url, :test_antifraud_url, :live_antifraud_url

      self.test_url = 'https://api.securepay.com.au/test/payment'
      self.live_url = 'https://api.securepay.com.au/xmlapi/payment'

      self.test_periodic_url = 'https://test.securepay.com.au/xmlapi/periodic'
      self.live_periodic_url = 'https://api.securepay.com.au/xmlapi/periodic'

      self.test_antifraud_url = 'https://test.securepay.com.au/antifraud/payment'
      self.live_antifraud_url = 'https://api.securepay.com.au/antifraud/payment'

      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

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
      # 21 Antifraud Payment
      # 22 Antifraud Request Only
      TRANSACTIONS = {
        :purchase => 0,
        :authorization => 10,
        :capture => 11,
        :void => 6,
        :refund => 4,
        :antifraud_purchase => 21,
        :antifraud_request => 22,
      }

      PERIODIC_ACTIONS = {
        :add_triggered    => "add",
        :remove_triggered => "delete",
        :trigger          => "trigger"
      }

      PERIODIC_TYPES = {
        :add_triggered    => 4,
        :remove_triggered => nil,
        :trigger          => nil
      }

      SUCCESS_CODES = [ '00', '08', '11', '16', '77' ]

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, credit_card_or_stored_id, options = {})
        if credit_card_or_stored_id.respond_to?(:number)
          requires!(options, :order_id)

          if options[:ip] && ((options[:fraud].nil? ? @options[:fraud] : options[:fraud]) == true)
            action = :antifraud_purchase
          else
            action = :purchase
          end

          commit action, build_purchase_request(money, credit_card_or_stored_id, options)
        else
          options[:billing_id] = credit_card_or_stored_id.to_s
          commit_periodic(build_periodic_item(:trigger, money, nil, options))
        end
      end

      # Does an antifraud check only, it does not complete the purchase.
      #
      # Takes the same arguments as #purchase, but works with a direct credit card number only, does not support a stored/billing ID
      def antifraud_request(money, credit_card, options = {})
        requires!(options, :order_id, options[:ip])

        commit :antifraud_request, build_purchase_request(money, credit_card_or_stored_id, options)
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

        if options[:ip]
          xml.tag! 'BuyerInfo' do
            billing_address = options[:billing_address] || options[:address]

            xml.tag! 'ip', options[:ip] unless options[:ip].blank?
            xml.tag! 'emailAddress', options[:email] unless options[:email].blank?

            unless billing_address[:name].blank?
              first_name, last_name = billing_address[:name].split(' ', 2)
              xml.tag! 'firstName', first_name unless first_name.blank?
              xml.tag! 'lastName', last_name unless last_name.blank?
            end

            xml.tag! 'zipCode', billing_address[:zip] unless billing_address[:zip].blank?
            xml.tag! 'town', billing_address[:suburb] unless billing_address[:city].blank?
            xml.tag! 'billingCountry', billing_address[:country] unless billing_address[:country].blank?
            xml.tag! 'deliveryCountry', options[:shipping_address][:country] unless (options[:shipping_address].nil? || options[:shipping_address][:country].blank?)
          end
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

      def commit(action, request)
        if [:antifraud_purchase, :antifraud_request].include?(action)
          url = test? ? self.test_antifraud_url : self.live_antifraud_url
        else
          url = test? ? self.test_url : self.live_url
        end

        response = parse(ssl_post(url, build_request(action, request)))

        Response.new(success?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response)
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
            xml.tag! 'PeriodicList', "count" => 1 do
              xml.tag! 'PeriodicItem', "ID" => 1 do
                xml << body
              end
            end
          end
        end
        xml.target!
      end

      def commit_periodic(request)
        my_request = build_periodic_request(request)
        #puts my_request
        response = parse(ssl_post(test? ? self.test_periodic_url : self.live_periodic_url, my_request))

        Response.new(success?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response)
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
