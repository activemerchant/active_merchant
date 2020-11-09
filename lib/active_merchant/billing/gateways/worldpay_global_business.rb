module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayGlobalBusinessGateway < Gateway
      self.test_url = 'https://secure-test.worldpay.com/jsp/merchant/xml/paymentService.jsp'
      self.live_url = 'https://secure.worldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = %w(HK GB AU AD BE CH CY CZ DE DK ES FI FR GI GR HU IE IT LI LU MC MT NL NO NZ PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]
      self.currencies_without_fractions = %w(HUF IDR ISK JPY KRW)
      self.currencies_with_three_decimal_places = %w(BHD KWD OMR RSD TND)
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'Worldpay Global'

      CARD_CODES = {
        'visa'             => 'VISA-SSL',
        'master'           => 'ECMC-SSL',
        'discover'         => 'DISCOVER-SSL',
        'american_express' => 'AMEX-SSL',
        'jcb'              => 'JCB-SSL',
        'maestro'          => 'MAESTRO-SSL',
        'laser'            => 'LASER-SSL',
        'diners_club'      => 'DINERS-SSL',
        'switch'           => 'MAESTRO-SSL'
      }

      STANDARD_ERROR_CODE_MAPPING = {
        '4'   => 'HOLD CARD',
        '5'   => 'REFUSED',
        '8'   => 'APPROVE AFTER IDENTIFICATION',
        '13'  => 'INVALID AMOUNT',
        '15'  => 'INVALID CARD ISSUER',
        '17'  => 'ANNULATION BY CLIENT',
        '28'  => 'ACCESS DENIED',
        '29'  => 'IMPOSSIBLE REFERENCE NUMBER',
        '33'  => 'CARD EXPIRED',
        '34'  => 'FRAUD SUSPICION',
        '38'  => 'SECURITY CODE EXPIRED',
        '41'  => 'LOST CARD',
        '43'  => 'STOLEN CARD, PICK UP',
        '51'  => 'LIMIT EXCEEDED',
        '55'  => 'INVALID SECURITY CODE',
        '56'  => 'UNKNOWN CARD',
        '57'  => 'ILLEGAL TRANSACTION',
        '62'  => 'RESTRICTED CARD',
        '63'  => 'SECURITY RULES VIOLATED',
        '75'  => 'SECURITY CODE INVALID',
        '76'  => 'CARD BLOCKED',
        '85'  => 'REJECTED BY CARD ISSUER',
        '973' => 'Revocation of authorization order',
        '975' => 'Revocation of all authorizations order',
      }

      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        requires!(options, :order_id)
        capture_request(money, payment_method, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<cardNumber>)\d+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cvc>)[^<]+(</cvc>)), '\1[FILTERED]\2')
      end

      private

      def capture_request(money, payment_method, options)
        commit('authorize', build_capture_request(money, payment_method, options))
      end

      def build_request
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct! :xml, :encoding => 'UTF-8'
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, "-//WorldPay//DTD WorldPay PaymentService v1//EN", "http://dtd.worldpay.com/paymentService_v1.dtd"
        xml.tag! 'paymentService', 'version' => "1.4", 'merchantCode' => (@options[:merchant_code] ? @options[:merchant_code] : @options[:username]) do
          yield xml
        end
        xml.target!
      end


      def build_capture_request(money, payment_method, options)
        build_request do |xml|
          xml.tag! 'submit' do
            xml.tag! 'order', 'orderCode' => options[:order_id] do
              xml.tag! 'description', options[:description].presence || "Purchase"
              add_amount(xml, money, options)
              add_payment_method(xml, money, payment_method, options)
              add_shopper(xml, options)
            end
          end
        end
      end

      def add_amount(xml, money, options)
        currency = options[:currency] || currency(money)

        amount_hash = {
          :value => localized_amount(money, currency),
          'currencyCode' => currency,
          'exponent' => currency_exponent(currency)
        }

        xml.tag! 'amount', amount_hash
      end

      def add_payment_method(xml, amount, payment_method, options)
        xml.tag! 'paymentDetails' do
          xml.tag! 'CARD-SSL' do
            xml.cardNumber payment_method.number
            xml.expiryDate do
              xml.date 'month' => payment_method.month, 'year' => payment_method.year
            end
            xml.tag! 'cardHolderName', payment_method.name
            add_address(xml, (options[:billing_address] || options[:address]))
          end
          add_session(xml, options)
        end
      end

      def add_session(xml, options)
        if options[:ip] && options[:session_id]
          xml.tag! 'session', 'shopperIPAddress' => options[:ip], 'id' => options[:session_id]
        else
          xml.tag! 'session', 'shopperIPAddress' => options[:ip] if options[:ip]
          xml.tag! 'session', 'id' => options[:session_id] if options[:session_id]
        end
      end

      def add_shopper(xml, options)
        return unless options[:email]
        xml.tag! 'shopper' do
          xml.tag! 'shopperEmailAddress', options[:email]
          if options[:user_agent].present?
            xml.tag! 'browser' do
              xml.tag! 'acceptHeader', 'text/html'
              xml.tag! 'userAgentHeader', options[:user_agent]
            end  
          end
        end
      end

      def add_address(xml, address)
        return unless address

        address = address_with_defaults(address)

        xml.tag! 'cardAddress' do
          xml.tag! 'address' do
            xml.tag! 'address1', address[:address1]
            xml.tag! 'address2', address[:address2] if address[:address2]
            xml.tag! 'postalCode', address[:zip]
            xml.tag! 'city', address[:city]
            xml.tag! 'state', address[:state]
            xml.tag! 'countryCode', address[:country]
          end
        end
      end

      def address_with_defaults(address)
        address ||= {}
        address.delete_if { |_, v| v.blank? }
        address.reverse_merge!(default_address)
      end

      def default_address
        {
          address1: 'N/A',
          zip: '0000',
          city: 'N/A',
          state: 'N/A',
          country: 'US'
        }
      end

      def parse(action, xml)
        parse_element({:action => action}, REXML::Document.new(xml))
      end

      def parse_element(raw, node)
        node.attributes.each do |k, v|
          raw["#{node.name.underscore}_#{k.underscore}".to_sym] = v
        end
        if node.has_elements?
          raw[node.name.underscore.to_sym] = true unless node.name.blank?
          node.elements.each{|e| parse_element(raw, e) }
        else
          raw[node.name.underscore.to_sym] = node.text unless node.text.nil?
        end
        raw
      end

      def headers(options = {})
        credentials = "#{@options[:username]}:#{@options[:password]}"

        {
          'Content-Type' => 'text/xml',
          'Authorization' => 'Basic ' + Base64.strict_encode64(credentials)
        }
      end

      def commit(action, request)
        xmr = ssl_post(url, request, headers)
        raw = parse(action, xmr)
        success, message = success_and_message_from(raw)

        Response.new(
          success,
          message,
          raw,
          :authorization => authorization_from(raw),
          :error_code => error_code_from(success, raw),
          :test => test?)

      rescue ActiveMerchant::ResponseError => e
        if e.response.code.to_s == "401"
          return Response.new(false, "Invalid credentials", {}, :test => test?)
        else
          raise e
        end
      end

      def url
        test? ? self.test_url : self.live_url
      end

      # success_criteria can be:
      #   - a string or an array of strings (if one of many responses)
      #   - An array of strings if one of many responses could be considered a
      #     success.
      def success_and_message_from(raw)
        success = (['AUTHORISED'].include?(raw[:last_event]) || raw[:ok].present?)
        if success
          message = "SUCCESS"
        else
          message = (raw[:iso8583_return_code_description] || raw[:error] || required_status_message(raw))
        end

        [ success, message ]
      end

      def error_code_from(success, raw)
        unless success == "SUCCESS"
          code = raw[:iso8583_return_code_code] || raw[:error_code] || nil

          STANDARD_ERROR_CODE_MAPPING.fetch(code, 'ERROR')      
        end
      end

      def required_status_message(raw, success_criteria)
        if(!['AUTHORISED'].include?(raw[:last_event]))
          "A transaction status of #{success_criteria.collect{|c| "'#{c}'"}.join(" or ")} is required."
        end
      end

      def authorization_from(raw)
        pair = raw.detect{|k,v| k.to_s =~ /_order_code$/}
        (pair ? pair.last : nil)
      end

      def currency_exponent(currency)
        return 0 if non_fractional_currency?(currency)
        return 3 if three_decimal_currency?(currency)
        return 2
      end
    end
  end
end
