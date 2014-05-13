module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AlfabankGateway < Gateway

      self.display_name        = 'Alfabank'
      self.homepage_url        = 'http://www.alfabank.ru'
      self.live_url            = 'https://engine.paymentgate.ru/payment/rest'
      self.money_format        = :cents
      self.ssl_strict          = false
      self.supported_cardtypes = [:visa, :master]
      self.supported_countries = ['RU']
      self.test_url            = 'https://test.paymentgate.ru/testpayment/rest'

      STATUSES_HASH = {
          '0' => 'Order registered but not paid',
          '1' => 'Waits when order will be completed',
          '2' => 'Run the full authorization amount of the order',
          '3' => 'Authorization revoked',
          '4' => 'The transaction had an operation return',
          '5' => 'Initiated ACS authorization through the issuing bank',
          '6' => 'Authorization rejected'
      }

      # Creates a new AlfabankGateway
      #
      # The gateway requires that valid credentials be passed in the +options+
      # hash.
      #
      # ==== Options
      #
      # * <tt>:account</tt> -- The Alfabank API account (REQUIRED)
      # * <tt>:secret</tt> -- The Alfabank API secret (REQUIRED)
      def initialize(options = {})
        requires!(options, :account, :secret)
        super
      end

      def make_order(options = {})
        post = {}
        add_order_number(post, options)
        add_return_url(post, options)
        add_amount(post, options)
        add_description(post, options)

        commit('register', options[:amount], post)
      end

      def get_order_status(options = {})
        post = {}
        add_order_number(post, options)
        add_order_id(post, options)

        commit('getOrderStatusExtended', nil, post)
      end

      private

      def add_order_number(post, options)
        post[:orderNumber] = options[:order_number]
      end

      def add_order_id(post, options)
        post[:orderId] = options[:order_id]
      end

      def add_return_url(post, options)
        post[:returnUrl] = options[:return_url]
      end

      def add_amount(post, options)
        post[:amount] = amount(options[:amount])
      end

      def add_description(post, options)
        post[:description] = options[:description]
      end

      def commit(action, money, parameters)
        base_url = (test? ? self.test_url : self.live_url)
        response = parse(ssl_post("#{base_url}/#{action}.do", post_data(action, parameters)))

        success = !has_error?(response)
        message = raw_message(response) || parse_status(response) || response['orderId']
        params  = convert_hash(response)

        Response.new(success, message, params)
      end

      def post_data(action, parameters = {})
        parameters.merge!({
                              :userName => @options[:account],
                              :password => @options[:secret]
                          }).to_query
      end

      def parse(response)
        ActiveSupport::JSON.decode(response)
      end

      def has_error?(response)
        response.blank? || !response['errorCode'].to_i.zero?
      end

      def raw_message(response)
        response['errorMessage']
      end

      def convert_hash(hash)
        Hash[hash.map { |key, value| [key.underscore, value] }]
      end

      def parse_status(response)
        STATUSES_HASH[response['orderStatus'].to_s]
      end
    end
  end
end
