module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    #
    # == Description
    #
    # Payment Gateway implementation for WorldPay's XML Direct API.
    #
    # References:
    # * WorldPay Direct XML technical documentation: http://www.worldpay.com/support/bg/xml/kb/3dsecure/dxml.html
    #
    # == Gateway Options
    #
    # In addition to the options supported by the Gateway base class the
    # Worldpay Gateway supports the following keys in the options hash:
    #
    # * <tt>:inst_id</tt> - The XML Invisible installation ID provided by
    #   WorldPay.
    # * <tt>:order_content</tt> - The order content in HTML format.
    # * <tt>:browser</tt> - A hash containing information about the shopper's
    #   browser - this is used to redirect the shopper to the correct issuer site
    #   for authentication.
    # * <tt>:session_id</tt> - A session ID uniquely identifying the shopper's
    #   browser session. WorldPay uses the session information for risk
    #   assessment. The session ID and shopper's IP address (:ip) are mandatory
    #   elements in a 3-D Secure transaction.
    # * <tt>:payer_authentication</tt> - A hash containing data for the 3-D
    #   Secure payer authentication protocol.
    # * <tt>:echo_data</tt> - An opaque string that may returned by the
    #   WorldPay gateway in the initial authentication response must be
    #   supplied in all subsequent requests as is. This is required for
    #   transactions using 3-D Secure payer authentication.
    # * <tt>:cookie</tt> - The gateway may set a HTTP session cookie on the
    #   initial authorize request. If that's the case the session cookie must
    #   be passed back to the gateway on all subsequent requests. This is
    #   requirement for 3-D Secure transactions.
    #
    # The <tt>:browser</tt> hash must have the following keys:
    # * <tt>:accept_header</tt> - The exact content of the HTTP accept header
    #   as sent to the merchant from the shopper's user agent.
    # * <tt>:user_agent</tt> - The exact content of the HTTP user-agent header
    #   as sent to the merchant from the shopper's user agent.
    #
    # The <tt>:payer_authentication</tt> hash must have the following keys:
    # * <tt>:pa_response</tt> - An opaque string that is returned by the issuer
    #   site once the payer authentication process is completed.
    #
    # == Gateway Response (3-D Secure)
    #
    # The gateway response to the initial authorize request may contain
    # additional attributes in the <tt>:params</tt> hash which indicate that
    # 3-D Secure payer authentication is required:
    #
    # * <tt>:request3_d_secure</tt> - A boolean that will be <tt>true</true> if
    #   additional 3-D Secure authentication is required.
    # * <tt>:issuer_url</tt> - The URL of the issuer's site to which the
    #   shopper must be redirected to complete 3-D Secure authentication.
    # * <tt>:pa_request</tt> - A opaque string that needs to be passed when
    #   redirecting the shopper to the issuer's site.
    # * <tt>:echo_data</tt> - A opaque string that needs to be passed back to
    #   the gateway in the second purchase request after the shopper returns from
    #   the issuer's site.
    # * <tt>:cookie</tt> - A session cookie set by the payment gateway which
    #   needs to be passed back in the second purchase request.
    #
    class WorldpayGateway < Gateway

      ##
      # Wrapper class for the default ActiveMerchant::Connection class that
      # extracts any cookies send by the gateway in a <tt>Set-Cookie</tt>
      # header in the response. The last captured cookie can be read from the
      # cookie attribute of the connection.
      class CaptureCookieConnection < ActiveMerchant::Connection

        # Value of the Set-Cookie header received in the last response from the
        # gateway or nil if the last response did not include any cookies.
        attr_reader :cookie

        def request(method, body, headers = {})
          result = super(method, body, headers)
          if result.key?('set-cookie')
            @cookie = result.to_hash['set-cookie'].map{|ea|ea[/^.*?;/]}.join
          else
            @cookie = nil
          end
          result
        end

      end

      # Instance of the CaptureCookieConnection class for the HTTPS connection to the Worldpay gateway.
      # This will be valid once the first request has been sent to the gateway.
      class_attribute :connection

      self.test_url = 'https://secure-test.worldpay.com/jsp/merchant/xml/paymentService.jsp'
      self.live_url = 'https://secure.worldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = ['HK', 'US', 'GB', 'AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser]
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'WorldPay'

      CARD_CODES = {
        'visa'             => 'VISA-SSL',
        'master'           => 'ECMC-SSL',
        'discover'         => 'DISCOVER-SSL',
        'american_express' => 'AMEX-SSL',
        'jcb'              => 'JCB-SSL',
        'maestro'          => 'MAESTRO-SSL',
        'laser'            => 'LASER-SSL'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process{authorize(money, payment_method, options)}
          r.process{capture(money, r.authorization, options.merge(:authorization_validated => true))}
        end
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)
        authorize_request(money, payment_method, options)
      end

      def capture(money, authorization, options = {})
        MultiResponse.run do |r|
          r.process{inquire_request(authorization, options, "AUTHORISED")} unless options[:authorization_validated]
          if r.params
            authorization_currency = r.params['amount_currency_code']
            options = options.merge(:currency => authorization_currency) if authorization_currency.present?
          end
          r.process{capture_request(money, authorization, options)}
        end
      end

      def void(authorization, options = {})
        MultiResponse.run do |r|
          r.process{inquire_request(authorization, options, "AUTHORISED")}
          r.process{cancel_request(authorization, options)}
        end
      end

      def refund(money, authorization, options = {})
        MultiResponse.run do |r|
          r.process{inquire_request(authorization, options, "CAPTURED")}
          r.process{refund_request(money, authorization, options)}
        end
      end

      private

      def authorize_request(money, payment_method, options)
        commit('authorize', build_authorization_request(money, payment_method, options), "AUTHORISED", options)
      end

      def capture_request(money, authorization, options)
        commit('capture', build_capture_request(money, authorization, options), :ok, options)
      end

      def cancel_request(authorization, options)
        commit('cancel', build_void_request(authorization, options), :ok, options)
      end

      def inquire_request(authorization, options, success_criteria)
        commit('inquiry', build_order_inquiry_request(authorization, options), success_criteria, options)
      end

      def refund_request(money, authorization, options)
        commit('inquiry', build_refund_request(money, authorization, options), :ok, options)
      end

      def build_request
        xml = Builder::XmlMarkup.new :indent => 0
        xml.instruct! :xml, :encoding => 'ISO-8859-1'
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
              if options[:browser]
                add_browser_details(xml, options[:browser])
              end
              if options[:echo_data]
                xml.tag! 'echoData' do
                  xml.cdata! options[:echo_data]
                end
              end
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
            add_amount(xml, money, options.merge(:debit_credit_indicator => "credit"))
          end
        end
      end

      def add_amount(xml, money, options)
        currency = options[:currency] || currency(money)
        amount   = localized_amount(money, currency)

        amount_hash = {
          :value => amount,
          'currencyCode' => currency,
          'exponent' => 2
        }

        if options[:debit_credit_indicator]
          amount_hash.merge!('debitCreditIndicator' => options[:debit_credit_indicator])
        end

        xml.tag! 'amount', amount_hash
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
            if options[:ip] && options[:session_id]
              add_session(xml, options[:ip], options[:session_id])
            end
            if options[:payer_authentication]
              add_3d_secure_info(xml, options[:payer_authentication])
            end
          end
        end
      end

      def add_browser_details(xml, browser)
        xml.tag! 'shopper' do
          xml.tag! 'browser' do
            xml.tag! 'acceptHeader', browser[:accept_header]
            xml.tag! 'userAgentHeader', browser[:user_agent]
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

      def add_3d_secure_info(xml, info_3d_secure)
        xml.tag! 'info3DSecure' do
          xml.tag! 'paResponse' do
            xml.cdata! info_3d_secure[:pa_response]
          end
        end
      end

      def add_session(xml, ip, session_id)
        xml.tag! 'session', 'shopperIPAddress' => ip, 'id' => session_id
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

      def commit(action, request, success_criteria, options)
        headers = {
          'Content-Type' => 'text/xml',
          'Authorization' => encoded_credentials
        }
        headers['Cookie'] = options[:cookie] if options[:cookie]

        xmr = ssl_post((test? ? self.test_url : self.live_url), request, headers)

        raw = parse(action, xmr)

        cookie = session_cookie(connection)
        raw[:cookie] = cookie if cookie

        Response.new(
          success_from(raw, success_criteria),
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

      def success_from(raw, success_criteria)
        (raw[:last_event] == success_criteria ||
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

      def localized_amount(money, currency)
        amount = amount(money)
        return amount unless CURRENCIES_WITHOUT_FRACTIONS.include?(currency.to_s)

        amount.to_i / 100 * 100
      end

      def new_connection(endpoint)
        self.connection = CaptureCookieConnection.new(endpoint)
      end

      def session_cookie(connection)
        if connection and connection.respond_to?(:cookie)
          connection.cookie
        end
      end
    end
  end
end
