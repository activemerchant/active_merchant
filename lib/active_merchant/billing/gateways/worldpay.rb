module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayGateway < Gateway
      TEST_URL = 'https://secure-test.wp3.rbsworldpay.com/jsp/merchant/xml/paymentService.jsp'
      LIVE_URL = 'https://secure.wp3.rbsworldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = ['HK', 'US', 'GB', 'AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro]
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'WorldPay'

      CARD_CODES = {
        'visa'             => 'VISA-SSL',
        'master'           => 'ECMC-SSL',
        'discover'         => 'DISCOVER-SSL',
        'american_express' => 'AMEX-SSL',
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def purchase(money, payment_method, options = {})
        response = MultiResponse.new
        response << authorize(money, payment_method, options)
        response << capture(money, response.authorization, options.merge(:authorization_validated => true)) if response.success?
        response
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)
        commit 'authorize', build_authorization_request(money, payment_method, options)
      end

      def capture(money, authorization, options = {})
        response = MultiResponse.new
        response << inquire(authorization, options) unless options[:authorization_validated]
        response << commit('capture', build_capture_request(money, authorization, options)) if response.success?
        response
      end

      def void(authorization, options = {})
        response = MultiResponse.new
        response << inquire(authorization, options)
        response << commit('cancel', build_void_request(authorization, options)) if response.success?
        response        
      end

      def refund(money, authorization, options = {})
        response = MultiResponse.new
        response << inquire(authorization, options)
        response << commit('refund', build_refund_request(money, authorization, options)) if response.success?
        response        
      end

      private

      def inquire(authorization, options={})
        commit 'inquiry', build_order_inquiry_request(authorization, options)
      end

      def build_request
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, "-//WorldPay//DTD WorldPay PaymentService v1//EN", "http://dtd.wp3.rbsworldpay.com/paymentService_v1.dtd"
        xml.tag! 'paymentService', 'version' => "1.4", 'merchantCode' => @options[:login] do
          yield xml
        end
        xml.target!
      end

      def build_order_modify_request(authorization)
        build_request do |xml|
          xml.tag! 'modify' do
            xml.tag! 'orderModification', 'orderCode' => authorization do
              yield xml
            end
          end
        end
      end

      def build_order_inquiry_request(authorization, options)
        build_request do |xml|
          xml.tag! 'inquiry' do
            xml.tag! 'orderInquiry', 'orderCode' => authorization
          end
        end
      end

      def build_authorization_request(money, payment_method, options)
        build_request do |xml|
          xml.tag! 'submit' do
            xml.tag! 'order', {'orderCode' => options[:order_id], 'installationId' => @options[:inst_id]}.reject{|_,v| !v} do
              xml.description(options[:description].blank? ? "Purchase" : options[:description])
              add_amount(xml, money, options)
              if options[:order_content]
                xml.tag! 'orderContent' do
                  xml.cdata! options[:order_content]
                end
              end
              add_payment_method(xml, money, payment_method, options)
            end
          end
        end
      end

      def build_capture_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'capture' do
            time = Time.now
            xml.tag! 'date', 'dayOfMonth' => time.day, 'month' => time.month, 'year'=> time.year
            add_amount(xml, money, options)
          end
        end
      end

      def build_void_request(authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'cancel'
        end
      end

      def build_refund_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'refund' do
            add_amount(xml, money, options)
          end
        end
      end

      def add_amount(xml, money, options)
        xml.tag! 'amount',
          :value => amount(money),
          'currencyCode' => (options[:currency] || currency(money)),
          'exponent' => 2
      end

      def add_payment_method(xml, amount, payment_method, options)
        if payment_method.is_a?(String)
          xml.tag! 'payAsOrder', 'orderCode' => payment_method do
            add_amount(xml, amount, options)
          end
        else
          xml.tag! 'paymentDetails' do
            xml.tag! CARD_CODES[card_brand(payment_method)] do
              xml.tag! 'cardNumber', payment_method.number
              xml.tag! 'expiryDate' do
                xml.tag! 'date', 'month' => format(payment_method.month, :two_digits), 'year' => format(payment_method.year, :four_digits)
              end

              xml.tag! 'cardHolderName', payment_method.name
              xml.tag! 'cvc', payment_method.verification_value

              add_address(xml, 'cardAddress', (options[:billing_address] || options[:address]))
            end
          end
        end
      end

      def add_address(xml, element, address)
        return if address.nil?

        xml.tag! element do
          xml.tag! 'address' do
            if m = /^\s*([^\s]+)\s+(.+)$/.match(address[:name])
              xml.tag! 'firstName', m[1]
              xml.tag! 'lastName', m[2]
            end
            if m = /^\s*(\d+)\s+(.+)$/.match(address[:address1])
              xml.tag! 'street', m[2]
              house_number = m[1]
            else
              xml.tag! 'street', address[:address1]
            end
            xml.tag! 'houseName', address[:address2] if address[:address2]
            xml.tag! 'houseNumber', house_number if house_number.present?
            xml.tag! 'postalCode', (address[:zip].present? ? address[:zip] : "0000")
            xml.tag! 'city', address[:city] if address[:city]
            xml.tag! 'state', (address[:state].present? ? address[:state] : 'N/A')
            xml.tag! 'countryCode', address[:country]
            xml.tag! 'telephoneNumber', address[:phone] if address[:phone]
          end
        end
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

      def commit(action, request)
        xmr = ssl_post((test? ? TEST_URL : LIVE_URL),
          request,
          'Content-Type' => 'text/xml',
          'Authorization' => encoded_credentials)

        raw = parse(action, xmr)

        Response.new(
          success_from(raw),
          message_from(raw),
          raw,
          :authorization => authorization_from(raw),
          :test => test?)

      rescue ActiveMerchant::ResponseError => e
        if e.response.code.to_s == "401"
          return Response.new(false, "Invalid credentials", {}, :test => test?)
        else
          raise e
        end
      end

      def success_from(raw)
        (raw[:last_event] == "AUTHORISED" ||
          raw[:ok].present?)
      end

      def message_from(raw)
        (raw[:iso8583_return_code_description] ||
          raw[:error] ||
          "SUCCESS")
      end

      def authorization_from(raw)
        pair = raw.detect{|k,v| k.to_s =~ /_order_code$/}
        (pair ? pair.last : nil)
      end

      def encoded_credentials
        credentials = "#{@options[:login]}:#{@options[:password]}"
        "Basic #{[credentials].pack('m').strip}"
      end

      class MultiResponse < Response
        attr_reader :responses

        def initialize
          @responses = []
        end

        def <<(response)
          if response.is_a?(MultiResponse)
            response.responses.each{|r| @responses << r}
          else
            @responses << response
          end
        end

        def success?
          @responses.all?{|r| r.success?}
        end

        %w(params message test authorization avs_result cvv_result test? fraud_review?).each do |m|
          class_eval %(
            def #{m}
              @responses.last.#{m}
            end
          )
        end
      end
    end
  end
end
