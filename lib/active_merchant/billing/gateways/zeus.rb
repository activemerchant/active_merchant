module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ZeusGateway < Gateway

      # NOTE: There are no separate URLs for test and live accounts.
      # The requests are distinguished only on the basis of test cards.
      self.test_url = 'https://linkpt.cardservice.co.jp/cgi-bin/secure.cgi'
      self.live_url = 'https://linkpt.cardservice.co.jp/cgi-bin/secure.cgi'

      self.supported_countries = ['JP']
      self.default_currency    = 'JPY'

      # All transactions happen in Japanese Yen.
      self.money_format        = :cents
      self.supported_cardtypes = [:visa, :master, :jcb, :american_express, :diners_club]
      self.homepage_url        = 'http://www.cardservice.co.jp/'
      self.display_name        = 'Zeus Credit Payment Service'

      STANDARD_ERRORS                = ['failure_order', 'Invalid', 'maintenance', 'connect error', 'failer_order']

      # clientip: IP code assigned to the merchant by Zeus (10 Digit).
      def initialize(options = {})
        requires!(options, :clientip)
        super
      end

      # money should be passed in Japanese Yen only.
      # Options:
      # => telno: Required Field
      # => If telnocheck=yes is passed, then email is sent out in English, otherwise, in Japanese.
      # => sendid is specific to a customer and is used for customer search when quickcharge is used.
      # => Use this end point for 'secure link purchase'.
      def purchase(money, credit_card, options = {})
        requires!(options, :telno)
        commit('sale', build_purchase_request(money, credit_card, options))
      end

      # NOTE: Please contact Zeus to enable authorization function.
      # Params:
      # =>  money: Amount in Japanese Yen.
      # =>  ordd: previously generated order id.
      # =>  Date format: yyyymmdd (String). Request fails if date is past.
      def authorize(money, ordd, date)
        commit('authonly', build_auth_request(money, ordd, date))
      end

      # You can capture +-5000 Yen of the authorized amount.
      # Params:
      # =>  money: Amount in Japanese Yen.
      # =>  ordd: The one used in authorization request.
      # =>  Date format: yyyymmdd (String). Request fails if date is past.
      def capture(money, ordd, date)
        commit('capture', build_capture_request(money, ordd, date))
      end

      def refund(ordd)
        commit('refund', build_refund_request(ordd))
      end

      private

      def build_purchase_request(money, credit_card, options)
        post = Hash[:send, 'mall']

        add_clientip(post)
        add_invoice(post, money, options)
        add_payment(post, credit_card)
        add_customer_data(post, options)
        add_extra_data(post, options)
        post
      end

      def build_refund_request(ordd)
        post = Hash.new

        add_clientip(post)
        add_refund_data(post, ordd)
        post
      end

      def build_auth_request(amount, ordd, date)
        post = Hash.new

        add_clientip(post)
        post[:king]   = amount
        post[:ordd]   = ordd
        post[:date]   = date
        post[:autype] = 'auth'
        post
      end

      def build_capture_request(amount, ordd, date)
        post = Hash.new

        add_clientip(post)
        post[:king]   = amount
        post[:ordd]   = ordd
        post[:date]   = date
        post[:autype] = 'sale'
        post
      end

      def add_refund_data(post, ordd)
        post[:ordd]   = ordd
        post[:return] = 'yes'
      end

      def add_customer_data(post, options)
        post[:telno]      = options[:telno]
        post[:email]      = options[:email]
        post[:sendid]     = options[:sendid]
        post[:telnocheck] = options[:telnocheck]
      end

      def add_extra_data(post, options)
        post[:sendpoint] = options[:sendpoint]
        post[:div]       = options[:div]
        post[:pubsec]    = options[:pubsec]
      end

      def add_invoice(post, money, options)
        post[:money]    = amount(money)
        post[:printord] = options[:printord]
      end

      # Add Credit card info.
      def add_payment(post, payment)
        post[:username]   = payment.name
        post[:cardnumber] = payment.number
        post[:expmm]      = payment.month
        post[:expyy]      = payment.year
        post[:seccode]    = payment.verification_value if payment.verification_value?
      end

      def add_clientip(post)
        post[:clientip] = self.options[:clientip]
      end

      def parse_sale(body)
        response = Hash.new
        response[:raw] = body
        response[:status], response[:ordd] = body.split(/\n/)
        response
      end

      def parse_refund(body)
        response = Hash.new
        response[:raw] = body
        response[:status], response[:message] = body.gsub(/[\n]+/, "\n").split(/\n/)
        response
      end

      def parse_authonly(body)
        { raw: body, status: body }
      end

      def parse_capture(body)
        parse_authonly(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = send("parse_#{ action }", ssl_post(url, post_data(parameters)))

        Response.new(
          success_from(response),
          message(response),
          response,
          test: test?,
          authorization: authorization(response) || parameters[:ordd],
          error_code: error_code(response)
        )
      end

      def success_from(response)
        !!(response[:raw].downcase =~ /success/)
      end

      def authorization(response)
        response[:ordd]
      end

      def message(response)
        response
      end

      def error_code(response)
        STANDARD_ERRORS.detect { |err_code| response[:raw].include?(err_code) }
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{ key }=#{ CGI.escape(value.to_s) }" }.join("&")
      end
    end
  end
end
