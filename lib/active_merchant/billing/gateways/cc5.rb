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

      def authorize(money, creditcard, options = {})
        # PreAuth
        request = build_sale_request('PreAuth', money, creditcard, options)

        commit('authonly', money, request)
      end

      def capture(money, authorization, options = {})
        # PostAuth
        commit('capture', money, post)
      end

      def purchase(money, creditcard, options = {})
        # Auth
        request = build_sale_request('Auth', money, creditcard, options)

        commit('sale', money, request)
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
          xml.tag! 'Expires', [format_exp(creditcard.month), format_exp(creditcard.year)].join('/')
          xml.tag! 'Cvv2Val', creditcard.verification_value
          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency] || currency(money))
          xml.tag! 'Email', options[:email]
          xml.tag! 'BillTo' do

          end

        end

        xml.target!
      end

      def format_exp(value)
        format(value, :two_digits)
      end

      def currency_code(currency)
        CURRENCY_CODES[currency] || CURRENCY_CODES[default_currency]
      end

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
      end

      def parse(body)
      end

      def commit(action, money, parameters)
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end

