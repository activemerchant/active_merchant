require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OptimalPaymentGateway < Gateway
      TEST_URL = 'https://webservices.test.optimalpayments.com/creditcardWS/CreditCardServlet/v1'
      LIVE_URL = 'https://webservices.optimalpayments.com/creditcardWS/CreditCardServlet/v1'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA', 'US', 'GB']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :solo] # :switch?

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.optimalpayments.com/'

      # The name of the gateway
      self.display_name = 'Optimal Payments'

      def initialize(options = {})
        #requires!(options, :login, :password)
        @options = options
        super
      end

      def authorize(money, card_or_auth, options = {})
        parse_card_or_auth(card_or_auth, options)
        commit("cc#{@stored_data}Authorize", money, options)
      end
      alias stored_authorize authorize # back-compat

      def purchase(money, card_or_auth, options = {})
        parse_card_or_auth(card_or_auth, options)
        commit("cc#{@stored_data}Purchase", money, options)
      end
      alias stored_purchase purchase # back-compat

      def refund(money, authorization, options = {})
        options[:confirmationNumber] = authorization
        commit('ccCredit', money, options)
      end

      def capture(money, authorization, options = {})
        options[:confirmationNumber] = authorization
        commit('ccSettlement', money, options)
      end

    private

      def parse_card_or_auth(card_or_auth, options)
        if card_or_auth.respond_to?(:number)
          @credit_card = card_or_auth
          @stored_data = ""
        else
          options[:confirmationNumber] = card_or_auth
          @stored_data = "StoredData"
        end
      end

      def parse(body)
        return Nokogiri::XML('') if body.nil?
        # received XML has odd xmlns that cause nokogiri to fail, so we just strip it out
        Nokogiri::XML(body.gsub(/ xmlns="(.*?")/, ''))
      end

      def commit(action, money, post)
        post[:order_id] ||= 'order_id'

        xml = case action
        when 'ccAuthorize', 'ccPurchase', 'ccVerification'
          cc_auth_request(money, post)
        when 'ccCredit', 'ccSettlement'
          cc_post_auth_request(money, post)
        when 'ccStoredDataAuthorize', 'ccStoredDataPurchase'
          cc_stored_data_request(money, post)
        #when 'ccCancelSettle', 'ccCancelCredit', 'ccCancelPayment'
        #  cc_cancel_request(money, post)
        #when 'ccPayment'
        #  cc_payment_request(money, post)
        #when 'ccAuthenticate'
        #  cc_authenticate_request(money, post)
        else
          raise 'Unknown Action'
        end
        txnRequest = URI.encode(xml)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, "txnMode=#{action}&txnRequest=#{txnRequest}"))

        Response.new(successful?(response), message_from(response), hash_from_xml(response),
          :test          => test?,
          :authorization => authorization_from(response)
        )
      end

      def successful?(response)
        response.xpath('//decision')[0].content == 'ACCEPTED' rescue false
      end

      def message_from(response)
        response.xpath('//detail').each do |detail|
          if detail.css('tag')[0].content == 'InternalResponseDescription'
            return detail.css('value')[0].content
          end
        end
        nil
      end

      def authorization_from(response)
        response.xpath('//confirmationNumber')[0].content rescue nil
      end

      def hash_from_xml(response)
        hsh = {}
        %w(confirmationNumber authCode
           decision code description
           actionCode avsResponse cvdResponse
           txnTime duplicateFound
        ).each do |tag|
          node = response.css(tag)[0]
          hsh[tag] = node.content if node
        end
        response.xpath('//detail').each do |detail|
          tag = detail.css('tag')[0].content
          value = detail.css('value')[0].content
          hsh[tag] = value
        end
        hsh
      end

      def xml_document(root_tag)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag!(root_tag, schema) do
          yield xml
        end
        xml.target!
      end

      def cc_auth_request(money, opts)
        xml_document('ccAuthRequestV1') do |xml|
          build_merchant_account(xml, @options)
          xml.merchantRefNum opts[:order_id]
          xml.amount(money/100.0)
          build_card(xml, opts)
          build_billing_details(xml, opts)
        end
      end

      def cc_post_auth_request(money, opts)
        xml_document('ccPostAuthRequestV1') do |xml|
          build_merchant_account(xml, @options)
          xml.confirmationNumber opts[:confirmationNumber]
          xml.merchantRefNum opts[:order_id]
          xml.amount(money/100.0)
        end
      end

      def cc_stored_data_request(money, opts)
        xml_document('ccStoredDataRequestV1') do |xml|
          build_merchant_account(xml, @options)
          xml.merchantRefNum opts[:order_id]
          xml.confirmationNumber opts[:confirmationNumber]
          xml.amount(money/100.0)
        end
      end

      # untested
      #
      # def cc_cancel_request(opts)
      #   xml_document('ccCancelRequestV1') do |xml|
      #     build_merchant_account(xml, @options)
      #     xml.confirmationNumber opts[:confirmationNumber]
      #   end
      # end
      #
      # def cc_payment_request(money, opts)
      #   xml_document('ccPaymentRequestV1') do |xml|
      #     build_merchant_account(xml, @options)
      #     xml.merchantRefNum opts[:order_id]
      #     xml.amount(money/100.0)
      #     build_card(xml, opts)
      #     build_billing_details(xml, opts)
      #   end
      # end
      #
      # def cc_authenticate_request(opts)
      #   xml_document('ccAuthenticateRequestV1') do |xml|
      #     build_merchant_account(xml, @options)
      #     xml.confirmationNumber opts[:confirmationNumber]
      #     xml.paymentResponse 'myPaymentResponse'
      #   end
      # end

      def schema
        { 'xmlns' => 'http://www.optimalpayments.com/creditcard/xmlschema/v1',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => 'http://www.optimalpayments.com/creditcard/xmlschema/v1'
        }
      end

      def build_merchant_account(xml, opts)
        xml.tag! 'merchantAccount' do
          xml.tag! 'accountNum' , opts[:account]
          xml.tag! 'storeID'    , opts[:login]
          xml.tag! 'storePwd'   , opts[:password]
        end
      end

      def build_card(xml, opts)
        xml.tag! 'card' do
          xml.tag! 'cardNum'      , @credit_card.number
          xml.tag! 'cardExpiry' do
            xml.tag! 'month'      , @credit_card.month
            xml.tag! 'year'       , @credit_card.year
          end
          if type = card_type(@credit_card.type)
            xml.tag! 'cardType'     , type
          end
          if @credit_card.verification_value
            xml.tag! 'cvdIndicator' , '1' # Value Provided
            xml.tag! 'cvd'          , @credit_card.verification_value
          end
        end
      end

      def build_billing_details(xml, opts)
        xml.tag! 'billingDetails' do
          addr = opts[:billing_address]
          xml.tag! 'cardPayMethod', 'WEB'
          if addr[:name]
            xml.tag! 'firstName', CGI.escape(addr[:name].split(' ').first) # TODO: parse properly
            xml.tag! 'lastName' , CGI.escape(addr[:name].split(' ').last )
          end
          xml.tag! 'street' , CGI.escape(addr[:address1]) if addr[:address1] && !addr[:address1].empty?
          xml.tag! 'street2', CGI.escape(addr[:address2]) if addr[:address2] && !addr[:address2].empty?
          xml.tag! 'city'   , CGI.escape(addr[:city]    ) if addr[:city]     && !addr[:city].empty?
          xml.tag! 'state'  , CGI.escape(addr[:state]   ) if addr[:state]    && !addr[:state].empty?
          xml.tag! 'country', CGI.escape(addr[:country] ) if addr[:country]  && !addr[:country].empty?
          xml.tag! 'zip'    , CGI.escape(addr[:zip]     ) # this one's actually required
          xml.tag! 'phone'  , CGI.escape(addr[:phone]   ) if addr[:phone]    && !addr[:phone].empty?
          #xml.tag! 'email'        , ''
        end
      end

      def card_type(key)
        { 'visa'            => 'VI',
          'master'          => 'MC',
          'american_express'=> 'AM',
          'discover'        => 'DI',
          'diners_club'     => 'DC',
          #'switch'          => '',
          'solo'            => 'SO'
        }[key]
      end

    end
  end
end

