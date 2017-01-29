module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GarantiGateway < Gateway
      self.live_url = 'https://sanalposprov.garanti.com.tr/VPServlet'
      self.test_url = 'https://sanalposprovtest.garanti.com.tr/VPServlet'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US','TR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://sanalposweb.garanti.com.tr'

      # The name of the gateway
      self.display_name = 'Garanti Sanal POS'

      self.default_currency = 'TRL'

      self.money_format = :cents

      CURRENCY_CODES = {
        'YTL' => 949,
        'TRL' => 949,
        'TL'  => 949,
        'USD' => 840,
        'EUR' => 978,
        'GBP' => 826,
        'JPY' => 392
      }


      def initialize(options = {})
        requires!(options, :login, :password, :terminal_id, :merchant_id)
        super
      end

      def purchase(money, credit_card, options = {})
        options = options.merge(:gvp_order_type => "sales")
        commit(money, build_sale_request(money, credit_card, options))
      end

      def authorize(money, credit_card, options = {})
        options = options.merge(:gvp_order_type => "preauth")
        commit(money, build_authorize_request(money, credit_card, options))
      end

      def capture(money, ref_id, options = {})
        options = options.merge(:gvp_order_type => "postauth")
        commit(money, build_capture_request(money, ref_id, options))
      end

      private

      def security_data
        rjusted_terminal_id = @options[:terminal_id].to_s.rjust(9, "0")
        Digest::SHA1.hexdigest(@options[:password].to_s + rjusted_terminal_id).upcase
      end

      def generate_hash_data(order_id, terminal_id, credit_card_number, amount, security_data)
        data = [order_id, terminal_id, credit_card_number, amount, security_data].join
        Digest::SHA1.hexdigest(data).upcase
      end

      def build_xml_request(money, credit_card, options, &block)
        card_number = credit_card.respond_to?(:number) ? credit_card.number : ''
        hash_data   = generate_hash_data(format_order_id(options[:order_id]), @options[:terminal_id], card_number, amount(money), security_data)

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

        xml.tag! 'GVPSRequest' do
          xml.tag! 'Mode', test? ? 'TEST' : 'PROD'
          xml.tag! 'Version', 'V0.01'
          xml.tag! 'Terminal' do
            xml.tag! 'ProvUserID', 'PROVAUT'
            xml.tag! 'HashData', hash_data
            xml.tag! 'UserID', @options[:login]
            xml.tag! 'ID', @options[:terminal_id]
            xml.tag! 'MerchantID', @options[:merchant_id]
          end

          if block_given?
            yield xml
          else
            xml.target!
          end
        end
      end

      def build_sale_request(money, credit_card, options)
        build_xml_request(money, credit_card, options) do |xml|
          add_customer_data(xml, options)
          add_order_data(xml, options) do
            add_addresses(xml, options)
          end
          add_credit_card(xml, credit_card)
          add_transaction_data(xml, money, options)

          xml.target!
        end
      end

      def build_authorize_request(money, credit_card, options)
         build_xml_request(money, credit_card, options) do |xml|
          add_customer_data(xml, options)
          add_order_data(xml, options)  do
            add_addresses(xml, options)
          end
          add_credit_card(xml, credit_card)
          add_transaction_data(xml, money, options)

          xml.target!
        end
      end

      def build_capture_request(money, ref_id, options)
        options = options.merge(:order_id => ref_id)
         build_xml_request(money, ref_id, options) do |xml|
          add_customer_data(xml, options)
          add_order_data(xml, options)
          add_transaction_data(xml, money, options)

          xml.target!
        end
      end

      def add_customer_data(xml, options)
        xml.tag! 'Customer' do
          xml.tag! 'IPAddress', options[:ip] || '1.1.1.1'
          xml.tag! 'EmailAddress', options[:email]
        end
      end

      def add_order_data(xml, options, &block)
        xml.tag! 'Order' do
          xml.tag! 'OrderID', format_order_id(options[:order_id])
          xml.tag! 'GroupID'

          if block_given?
            yield xml
          end
        end
      end

      def add_credit_card(xml, credit_card)
        xml.tag! 'Card' do
          xml.tag! 'Number', credit_card.number
          xml.tag! 'ExpireDate', [format_exp(credit_card.month), format_exp(credit_card.year)].join
          xml.tag! 'CVV2', credit_card.verification_value
        end
      end

      def format_exp(value)
        format(value, :two_digits)
      end

      # OrderId field must be A-Za-z0-9_ format and max 36 char
      def format_order_id(order_id)
        order_id.to_s.gsub(/[^A-Za-z0-9_]/, '')[0...36]
      end

      def add_addresses(xml, options)
        xml.tag! 'AddressList' do
          if billing_address = options[:billing_address] || options[:address]
            xml.tag! 'Address' do
              xml.tag! 'Type', 'B'
              add_address(xml, billing_address)
            end
          end

          if options[:shipping_address]
            xml.tag! 'Address' do
              xml.tag! 'Type', 'S'
              add_address(xml, options[:shipping_address])
            end
          end
        end
      end

      def add_address(xml, address)
        xml.tag! 'Name', normalize(address[:name])
        address_text = address[:address1]
        address_text << " #{ address[:address2]}" if address[:address2]
        xml.tag! 'Text', normalize(address_text)
        xml.tag! 'City', normalize(address[:city])
        xml.tag! 'District', normalize(address[:state])
        xml.tag! 'PostalCode', address[:zip]
        xml.tag! 'Country', normalize(address[:country])
        xml.tag! 'Company', normalize(address[:company])
        xml.tag! 'PhoneNumber', address[:phone].to_s.gsub(/[^0-9]/, '') if address[:phone]
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

      def add_transaction_data(xml, money, options)
        xml.tag! 'Transaction' do
          xml.tag! 'Type', options[:gvp_order_type]
          xml.tag! 'Amount', amount(money)
          xml.tag! 'CurrencyCode', currency_code(options[:currency] || currency(money))
          xml.tag! 'CardholderPresentCode', 0
        end
      end

      def currency_code(currency)
        CURRENCY_CODES[currency] || CURRENCY_CODES[default_currency]
      end

      def commit(money,request)
        url = test? ? self.test_url : self.live_url
        raw_response = ssl_post(url, "data=" + request)
        response = parse(raw_response)

        success = success?(response)

        Response.new(success,
                     success ? 'Approved' : "Declined (Reason: #{response[:reason_code]} - #{response[:error_msg]} - #{response[:sys_err_msg]})",
                     response,
                     :test => test?,
                     :authorization => response[:order_id])
      end

      def parse(body)
        xml = REXML::Document.new(strip_invalid_xml_chars(body))

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

      def strip_invalid_xml_chars(xml)
        xml.gsub(/&(?!(?:[a-z]+|#[0-9]+|x[a-zA-Z0-9]+);)/, '&amp;')
      end

    end
  end
end

