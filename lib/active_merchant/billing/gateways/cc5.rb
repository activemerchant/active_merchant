module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # CC5 API is used by many banks in Turkey. Extend this base class to provide
    # concrete implementations.
    class CC5Gateway < Gateway
      self.default_currency = 'TRY'

      CURRENCY_CODES = {
        'TRY' => 949,
        'YTL' => 949,
        'TRL' => 949,
        'TL'  => 949,
        'USD' => 840,
        'EUR' => 978,
        'GBP' => 826,
        'JPY' => 392
      }

      def initialize(options = {})
        requires!(options, :login, :password, :client_id)
        super
      end

      def purchase(money, creditcard, options = {})
        commit(build_sale_request('Auth', money, creditcard, options))
      end

      def authorize(money, creditcard, options = {})
        commit(build_sale_request('PreAuth', money, creditcard, options))
      end

      def capture(money, authorization, options = {})
        commit(build_capture_request(money, authorization, options))
      end

      def void(authorization, options = {})
        commit(build_void_request(authorization, options))
      end

      def refund(money, authorization, options = {})
        commit(build_authorization_credit_request(money, authorization, options))
      end

      def credit(money, creditcard, options = {})
        commit(build_creditcard_credit_request(money, creditcard, options))
      end

      protected

      def build_sale_request(type, money, creditcard, options = {})
        requires!(options,  :order_id)

        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          add_login_tags(xml)
          xml.tag! 'OrderId', options[:order_id]
          xml.tag! 'Type', type
          xml.tag! 'Number', creditcard.number
          xml.tag! 'Expires', [format(creditcard.month, :two_digits), format(creditcard.year, :two_digits)].join('/')
          xml.tag! 'Cvv2Val', creditcard.verification_value
          add_amount_tags(money, options, xml)
          xml.tag! 'Email', options[:email] if options[:email]

          if(address = (options[:billing_address] || options[:address]))
            xml.tag! 'BillTo' do
              add_address(xml, address)
            end
            xml.tag! 'ShipTo' do
              add_address(xml, address)
            end
          end

        end

        xml.target!
      end

      def build_capture_request(money, authorization, options = {})
        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          add_login_tags(xml)
          xml.tag! 'OrderId', authorization
          xml.tag! 'Type', 'PostAuth'
          add_amount_tags(money, options, xml)
        end
      end

      def build_void_request(authorization, options = {})
        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          add_login_tags(xml)
          xml.tag! 'OrderId', authorization
          xml.tag! 'Type', 'Void'
        end
      end

      def build_authorization_credit_request(money, authorization, options = {})
        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          add_login_tags(xml)
          xml.tag! 'OrderId', authorization
          xml.tag! 'Type', 'Credit'
          add_amount_tags(money, options, xml)
        end
      end

      def build_creditcard_credit_request(money, creditcard, options = {})
        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          add_login_tags(xml)
          xml.tag! 'Type', 'Credit'
          xml.tag! 'Number', creditcard.number

          add_amount_tags(money, options, xml)
        end
      end

      def add_address(xml, address)
        xml.tag! 'Name', normalize(address[:name])
        xml.tag! 'Street1', normalize(address[:address1])
        xml.tag! 'Street2', normalize(address[:address2]) if address[:address2]
        xml.tag! 'City', normalize(address[:city])
        xml.tag! 'PostalCode', address[:zip]
        xml.tag! 'Country', normalize(address[:country])
        xml.tag! 'Company', normalize(address[:company])
        xml.tag! 'TelVoice', address[:phone].to_s.gsub(/[^0-9]/, '') if address[:phone]
      end

      def add_login_tags(xml)
        xml.tag! 'Name', @options[:login]
        xml.tag! 'Password', @options[:password]
        xml.tag! 'ClientId', @options[:client_id]
        xml.tag! 'Mode', (test? ? 'T' : 'P')
      end

      def add_amount_tags(money, options, xml)
        xml.tag! 'Total', amount(money)
        xml.tag! 'Currency', currency_code(options[:currency] || currency(money))
      end

      def currency_code(currency)
        (CURRENCY_CODES[currency] || CURRENCY_CODES[default_currency])
      end

      def commit(request)
        raw_response = ssl_post((test? ? self.test_url : self.live_url), "DATA=" + request)

        response = parse(raw_response)

        success = success?(response)

        Response.new(
          success,
          (success ? 'Approved' : "Declined (Reason: #{response[:proc_return_code]} - #{response[:err_msg]})"),
          response,
          :test => test?,
          :authorization => response[:order_id]
        )
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

      def success?(response)
        (response[:response] == "Approved")
      end

      def normalize(text)
        return unless text

        if ActiveSupport::Inflector.method(:transliterate).arity == -2
          ActiveSupport::Inflector.transliterate(text,'')
        elsif RUBY_VERSION >= '1.9'
          text.gsub(/[^\x00-\x7F]+/, '')
        else
          ActiveSupport::Inflector.transliterate(text).to_s
        end
      end
    end
  end
end
