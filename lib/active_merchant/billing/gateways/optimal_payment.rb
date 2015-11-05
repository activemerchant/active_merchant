module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OptimalPaymentGateway < Gateway
      self.test_url = 'https://webservices.test.optimalpayments.com/creditcardWS/CreditCardServlet/v1'
      self.live_url = 'https://webservices.optimalpayments.com/creditcardWS/CreditCardServlet/v1'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA', 'US', 'GB']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :solo] # :switch?

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.optimalpayments.com/'

      # The name of the gateway
      self.display_name = 'Optimal Payments'

      def initialize(options = {})

        if(options[:login])
          ActiveMerchant.deprecated("The 'login' option is deprecated in favor of 'store_id' and will be removed in a future version.")
          options[:store_id] = options[:login]
        end

        if(options[:account])
          ActiveMerchant.deprecated("The 'account' option is deprecated in favor of 'account_number' and will be removed in a future version.")
          options[:account_number] = options[:account]
        end

        requires!(options, :account_number, :store_id, :password)
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

      def void(authorization, options = {})
        options[:confirmationNumber] = authorization
        commit('ccAuthorizeReversal', nil, options)
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
        REXML::Document.new(body || '')
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
        when 'ccAuthorizeReversal'
          cc_auth_reversal_request(post)
        #when 'ccCancelSettle', 'ccCancelCredit', 'ccCancelPayment'
        #  cc_cancel_request(money, post)
        #when 'ccPayment'
        #  cc_payment_request(money, post)
        #when 'ccAuthenticate'
        #  cc_authenticate_request(money, post)
        else
          raise 'Unknown Action'
        end
        txnRequest = escape_uri(xml)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, "txnMode=#{action}&txnRequest=#{txnRequest}"))

        Response.new(successful?(response), message_from(response), hash_from_xml(response),
          :test          => test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => avs_result_from(response) },
          :cvv_result => cvv_result_from(response)
        )
      end

      # The upstream is picky and so we can't use CGI.escape like we want to
      def escape_uri(uri)
        URI::DEFAULT_PARSER.escape(uri)
      end

      def successful?(response)
        REXML::XPath.first(response, '//decision').text == 'ACCEPTED' rescue false
      end

      def message_from(response)
        REXML::XPath.each(response, '//detail') do |detail|
          if detail.is_a?(REXML::Element) && detail.elements['tag'].text == 'InternalResponseDescription'
            return detail.elements['value'].text
          end
        end
        nil
      end

      def authorization_from(response)
        get_text_from_document(response, '//confirmationNumber')
      end

      def avs_result_from(response)
        get_text_from_document(response, '//avsResponse')
      end

      def cvv_result_from(response)
        get_text_from_document(response, '//cvdResponse')
      end

      def hash_from_xml(response)
        hsh = {}
        %w(confirmationNumber authCode
           decision code description
           actionCode avsResponse cvdResponse
           txnTime duplicateFound
        ).each do |tag|
          node = REXML::XPath.first(response, "//#{tag}")
          hsh[tag] = node.text if node
        end
        REXML::XPath.each(response, '//detail') do |detail|
          next unless detail.is_a?(REXML::Element)
          tag = detail.elements['tag'].text
          value = detail.elements['value'].text
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

      def get_text_from_document(document, node)
        node = REXML::XPath.first(document, node)
        node && node.text
      end

      def cc_auth_request(money, opts)
        xml_document('ccAuthRequestV1') do |xml|
          build_merchant_account(xml)
          xml.merchantRefNum opts[:order_id]
          xml.amount(money/100.0)
          build_card(xml, opts)
          build_billing_details(xml, opts)
          build_shipping_details(xml, opts)
          xml.customerIP opts[:ip] if opts[:ip]
        end
      end

      def cc_auth_reversal_request(opts)
        xml_document('ccAuthReversalRequestV1') do |xml|
          build_merchant_account(xml)
          xml.confirmationNumber opts[:confirmationNumber]
          xml.merchantRefNum opts[:order_id]
        end
      end

      def cc_post_auth_request(money, opts)
        xml_document('ccPostAuthRequestV1') do |xml|
          build_merchant_account(xml)
          xml.confirmationNumber opts[:confirmationNumber]
          xml.merchantRefNum opts[:order_id]
          xml.amount(money/100.0)
        end
      end

      def cc_stored_data_request(money, opts)
        xml_document('ccStoredDataRequestV1') do |xml|
          build_merchant_account(xml)
          xml.merchantRefNum opts[:order_id]
          xml.confirmationNumber opts[:confirmationNumber]
          xml.amount(money/100.0)
        end
      end

      # untested
      #
      # def cc_cancel_request(opts)
      #   xml_document('ccCancelRequestV1') do |xml|
      #     build_merchant_account(xml)
      #     xml.confirmationNumber opts[:confirmationNumber]
      #   end
      # end
      #
      # def cc_payment_request(money, opts)
      #   xml_document('ccPaymentRequestV1') do |xml|
      #     build_merchant_account(xml)
      #     xml.merchantRefNum opts[:order_id]
      #     xml.amount(money/100.0)
      #     build_card(xml, opts)
      #     build_billing_details(xml, opts)
      #   end
      # end
      #
      # def cc_authenticate_request(opts)
      #   xml_document('ccAuthenticateRequestV1') do |xml|
      #     build_merchant_account(xml)
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

      def build_merchant_account(xml)
        xml.tag! 'merchantAccount' do
          xml.tag! 'accountNum' , @options[:account_number]
          xml.tag! 'storeID'    , @options[:store_id]
          xml.tag! 'storePwd'   , @options[:password]
        end
      end

      def build_card(xml, opts)
        xml.tag! 'card' do
          xml.tag! 'cardNum'      , @credit_card.number
          xml.tag! 'cardExpiry' do
            xml.tag! 'month'      , @credit_card.month
            xml.tag! 'year'       , @credit_card.year
          end
          if brand = card_type(@credit_card.brand)
            xml.tag! 'cardType'     , brand
          end
          if @credit_card.verification_value
            xml.tag! 'cvdIndicator' , '1' # Value Provided
            xml.tag! 'cvd'          , @credit_card.verification_value
          end
        end
      end

      def build_billing_details(xml, opts)
        xml.tag! 'billingDetails' do
          xml.tag! 'cardPayMethod', 'WEB'
          build_address(xml, opts[:billing_address]) if opts[:billing_address]
          xml.tag! 'email', opts[:email] if opts[:email]
        end
      end

      def build_shipping_details(xml, opts)
        xml.tag! 'shippingDetails' do
          build_address(xml, opts[:shipping_address])
          xml.tag! 'email', opts[:email] if opts[:email]
        end if opts[:shipping_address].present?
      end

      def build_address(xml, addr)
        if addr[:name]
          first_name, last_name = split_names(addr[:name])
          xml.tag! 'firstName', first_name
          xml.tag! 'lastName' , last_name
        end
        xml.tag! 'street' , addr[:address1] if addr[:address1].present?
        xml.tag! 'street2', addr[:address2] if addr[:address2].present?
        xml.tag! 'city'   , addr[:city]     if addr[:city].present?
        if addr[:state].present?
          state_tag = %w(US CA).include?(addr[:country]) ? 'state' : 'region'
          xml.tag! state_tag, addr[:state]
        end
        xml.tag! 'country', addr[:country]  if addr[:country].present?
        xml.tag! 'zip'    , addr[:zip]      if addr[:zip].present?
        xml.tag! 'phone'  , addr[:phone]    if addr[:phone].present?
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
