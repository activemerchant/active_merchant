module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # CC5 API is used by many banks in Turkey. Extend this base class to provide concrete implementations.
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
        request = build_sale_request('Auth', money, creditcard, options)
        commit(request)
      end

      def authorize(money, creditcard, options = {})
        request = build_sale_request('PreAuth', money, creditcard, options)
        commit(request)
      end

      def capture(money, authorization, options = {})
        # PostAuth
        commit('capture', money, post)
      end

      protected

      def build_sale_request(type, money, creditcard, options = {})
        xml = Builder::XmlMarkup.new :indent => 2

        xml.tag! 'CC5Request' do
          xml.tag! 'Name', options[:login]
          xml.tag! 'Password', options[:password]
          xml.tag! 'ClientId', options[:client_id]
          xml.tag! 'OrderId', options[:order_id]
          xml.tag! 'Type', type
          xml.tag! 'Number', creditcard.number
          xml.tag! 'Expires', [two_digits(creditcard.month), two_digits(creditcard.year)].join('/')
          xml.tag! 'Cvv2Val', creditcard.verification_value
          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency] || currency(money))
          xml.tag! 'Email', options[:email]

          if address = options[:address]
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

      def currency_code(currency)
        CURRENCY_CODES[currency] || CURRENCY_CODES[default_currency]
      end

      def commit(request)
        raw_response = ssl_post(self.live_url, "DATA=" + request)
        response = parse(raw_response)

        success = success?(response)

        Response.new(success,
                     success ? 'Approved' : "Declined (Reason: #{response[:proc_return_code]} - #{response[:err_msg]})",
                     response,
                     :test => test?,
                     :authorization => response[:order_id])
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
        response[:message] == "Approved"
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
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

      def two_digits(value)
        format(value, :two_digits)
      end

    end
  end
end

