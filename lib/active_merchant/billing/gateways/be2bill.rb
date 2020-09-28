require "digest/sha2"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Be2billGateway < Gateway
      self.test_url = 'https://secure-test.be2bill.com/front/service/rest/process.php'
      self.live_url = 'https://secure-magenta1.be2bill.com/front/service/rest/process.php'

      self.display_name = 'Be2Bill'
      self.homepage_url = 'http://www.be2bill.com/'
      self.supported_countries = ['FR']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.default_currency = 'EUR'
      self.money_format = :cents

      # These options are mandatory on be2bill (cf. tests) :
      #
      # options = { :order_id    => order.id,
      #             :customer_id => user.id,
      #             :description => "Some description",
      #             :referrer    => request.env['HTTP_REFERER'],
      #             :user_agent  => request.env['HTTP_USER_AGENT'],
      #             :ip          => request.remote_ip,
      #             :email       => user.email }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)

        commit('authorization', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)

        commit('payment', money, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, options)
        post[:TRANSACTIONID] = authorization

        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
        post[:CLIENTREFERRER]  = options[:referrer]
        post[:CLIENTUSERAGENT] = options[:user_agent]
        post[:CLIENTIP]        = options[:ip]
        post[:CLIENTEMAIL]     = options[:email]
        post[:CLIENTIDENT]     = options[:customer_id]
      end

      def add_invoice(post, options)
        post[:ORDERID]     = options[:order_id]
        post[:DESCRIPTION] = options[:description]
      end

      def add_creditcard(post, creditcard)
        post[:CARDFULLNAME]     = creditcard ? creditcard.name : ''
        post[:CARDCODE]         = creditcard ? creditcard.number : ''
        post[:CARDVALIDITYDATE] = creditcard ? "%02d-%02s" % [creditcard.month, creditcard.year.to_s[-2..-1]] : ''
        post[:CARDCVV]          = creditcard ? creditcard.verification_value : ''
      end

      def parse(response)
        ActiveSupport::JSON.decode(response)
      end

      def commit(action, money, parameters)
        parameters[:IDENTIFIER] = @options[:login]
        parameters[:AMOUNT]     = amount(money)
        parameters[:VERSION]    = '2.0'

        url = (test? ? self.test_url : self.live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          successful?(response),
          message_from(response),
          response,
          :authorization => response['TRANSACTIONID'],
          :test          => test?
        )
      end

      def successful?(response)
        %w(0000 0001).include?(response['EXECCODE'])
      end

      def message_from(response)
        if successful?(response)
          "Approved : #{response['MESSAGE']}"
        else
          "Declined (#{response['EXECCODE']} - #{response['MESSAGE']}"
        end
      end

      def post_data(action, parameters = {})
        {
          :method => action,
          :params => parameters.merge(HASH: signature(parameters, action))
        }.to_query
      end

      def signature(parameters, action)
        parameters[:OPERATIONTYPE] = action unless parameters[:OPERATIONTYPE]

        signature = @options[:password]
        parameters.sort.each do |key, value|
          signature += ("#{key.upcase}=#{value}" + @options[:password])
        end

        Digest::SHA256.hexdigest(signature)
      end
    end
  end
end
