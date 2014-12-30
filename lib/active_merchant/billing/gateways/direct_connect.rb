module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DirectConnectGateway < Gateway
      self.test_url = 'https://gateway.1directconnect.com/'
      self.live_url = 'https://gateway.1directconnect.com/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.directconnectps.com/'
      self.display_name = 'Direct Connect'

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_authentication(post, options)
        post[:transType] = 'sale'
        commit(:saleCreditCard, post)
      end



      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_authentication(post, options)
        post[:username] = @username
        post[:password] = @password
      end

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        exp_date = payment.expiry_date.expiration.strftime('%02m%02y')

        post[:cardnum] = payment.number
        post[:expdate] = "#{exp_date}"
        puts "exp date #{exp_date}"
      end

      def parse(body)
        {}
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        service = actionToService(action)
        url = "#{url}#{serviceUrl(service)}"
        puts url
        begin
          response = parse(ssl_post(url, post_data(action, parameters)))
        rescue ResponseError => e
          puts e.response.body
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
        return nil unless parameters

        parameters.map do |k, v|
          "#{k}=#{CGI.escape(v.to_s)}"
        end.compact.join('&')
      end

      def actionToService(action)
        case action
        when :authCreditCard, :saleCreditCard, :returnCreditCard, :voidCreditCard
          :processCreditCard
        when :saleCheck, :authCheck, :returnCheck, :voidCheck
          :processCheck
        else
          action
        end
      end

      def serviceUrl(service)
        case service
        when :processCreditCard
          "ws/transact.asmx/ProcessCreditCard"
        when :processCheck
          "ws/transact.asmx/ProcessCheck"
        when :storeCardSafeCard
          "ws/cardsafe.asmx/StoreCard"
        when :processCardRecurring
          "ws/recurring.asmx/ProcessCreditCard"
        end
      end
    end
  end
end
