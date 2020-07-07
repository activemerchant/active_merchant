module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SoEasyPayGateway < Gateway
      self.live_url = self.test_url = 'https://secure.soeasypay.com/gateway.asmx'
      self.money_format = :cents

      self.supported_countries = %w[
        US CA AT BE BG HR CY CZ DK EE
        FI FR DE GR HU IE IT LV LT LU
        MT NL PL PT RO SK SI ES SE GB
        IS NO CH
      ]
      self.supported_cardtypes = %i[visa master american_express discover maestro jcb diners_club]
      self.homepage_url = 'http://www.soeasypay.com/'
      self.display_name = 'SoEasyPay'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, payment_source, options = {})
        if payment_source.respond_to?(:number)
          commit('AuthorizeTransaction', do_authorization(money, payment_source, options), options)
        else
          commit('ReauthorizeTransaction', do_reauthorization(money, payment_source, options), options)
        end
      end

      def purchase(money, payment_source, options = {})
        if payment_source.respond_to?(:number)
          commit('SaleTransaction', do_sale(money, payment_source, options), options)
        else
          commit('RebillTransaction', do_rebill(money, payment_source, options), options)
        end
      end

      def capture(money, authorization, options = {})
        commit('CaptureTransaction', do_capture(money, authorization, options), options)
      end

      def refund(money, authorization, options={})
        commit('RefundTransaction', do_refund(money, authorization, options), options)
      end

      def void(authorization, options={})
        commit('CancelTransaction', do_void(authorization, options), options)
      end

      private

      def do_authorization(money, card, options)
        build_soap('AuthorizeTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options)
          fill_cardholder(soap, card, options)
          fill_card(soap, card)
        end
      end

      def do_sale(money, card, options)
        build_soap('SaleTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options)
          fill_cardholder(soap, card, options)
          fill_card(soap, card)
        end
      end

      def do_reauthorization(money, authorization, options)
        build_soap('ReauthorizeTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options)
          fill_transaction_id(soap, authorization)
        end
      end

      def do_rebill(money, authorization, options)
        build_soap('RebillTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options)
          fill_transaction_id(soap, authorization)
        end
      end

      def do_capture(money, authorization, options)
        build_soap('CaptureTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options, :no_currency)
          fill_transaction_id(soap, authorization)
        end
      end

      def do_refund(money, authorization, options)
        build_soap('RefundTransaction') do |soap|
          fill_credentials(soap, options)
          fill_order_info(soap, money, options, :no_currency)
          fill_transaction_id(soap, authorization)
        end
      end

      def do_void(authorization, options)
        build_soap('CancelTransaction') do |soap|
          fill_credentials(soap, options)
          fill_transaction_id(soap, authorization)
        end
      end

      def fill_credentials(soap, options)
        soap.tag!('websiteID', @options[:login].to_s)
        soap.tag!('password', @options[:password].to_s)
      end

      def fill_cardholder(soap, card, options)
        ch_info = options[:billing_address] || options[:address]

        soap.tag!('customerIP', options[:ip].to_s)
        name = card.name || ch_info[:name]
        soap.tag!('cardHolderName', name.to_s)
        address = ch_info[:address1] || ''
        address << ch_info[:address2] if ch_info[:address2]
        soap.tag!('cardHolderAddress', address.to_s)
        soap.tag!('cardHolderZipcode', ch_info[:zip].to_s)
        soap.tag!('cardHolderCity', ch_info[:city].to_s)
        soap.tag!('cardHolderState', ch_info[:state].to_s)
        soap.tag!('cardHolderCountryCode', ch_info[:country].to_s)
        soap.tag!('cardHolderPhone', ch_info[:phone].to_s)
        soap.tag!('cardHolderEmail', options[:email].to_s)
      end

      def fill_transaction_id(soap, transaction_id)
        soap.tag!('transactionID', transaction_id.to_s)
      end

      def fill_card(soap, card)
        soap.tag!('cardNumber', card.number.to_s)
        soap.tag!('cardSecurityCode', card.verification_value.to_s)
        soap.tag!('cardExpireMonth', card.month.to_s.rjust(2, '0'))
        soap.tag!('cardExpireYear', card.year.to_s)
      end

      def fill_order_info(soap, money, options, skip_currency=false)
        soap.tag!('orderID', options[:order_id].to_s)
        soap.tag!('orderDescription', "Order #{options[:order_id]}")
        soap.tag!('amount', amount(money).to_s)
        soap.tag!('currency', (options[:currency] || currency(money)).to_s) unless skip_currency
      end

      def parse(response, action)
        result = {}
        document = REXML::Document.new(response)
        response_element = document.root.get_elements("//*[@xsi:type='tns:#{action}Response']").first
        response_element.elements.each do |element|
          result[element.name.underscore] = element.text
        end
        result
      end

      def commit(soap_action, soap, options)
        headers = {'SOAPAction' => "\"urn:Interface##{soap_action}\"",
                   'Content-Type' => 'text/xml; charset=utf-8'}
        response_string = ssl_post(test? ? self.test_url : self.live_url, soap, headers)
        response = parse(response_string, soap_action)
        return Response.new(response['errorcode'] == '000',
          response['errormessage'],
          response,
          test: test?,
          authorization: response['transaction_id'])
      end

      def build_soap(request)
        retval = Builder::XmlMarkup.new(indent: 2)
        retval.instruct!(:xml, version: '1.0', encoding: 'utf-8')
        retval.tag!('soap:Envelope', {
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/',
          'xmlns:tns' => 'urn:Interface',
          'xmlns:types' => 'urn:Interface/encodedTypes',
          'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
        }) do
          retval.tag!('soap:Body', {'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/'}) do
            retval.tag!("tns:#{request}") do
              retval.tag!("#{request}Request", {'xsi:type' => "tns:#{request}Request"}) do
                yield retval
              end
            end
          end
        end
        retval.target!
      end
    end
  end
end
