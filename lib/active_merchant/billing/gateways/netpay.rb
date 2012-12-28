module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    #
    # NETPAY Gateway
    #
    # Support for NETPAY's HTTP Connector payment gateway in Mexico.
    #
    # The gateway sends requests as HTTP POST and receives the response details
    # in the HTTP header, making the process really rather simple.
    #
    #
    class NetpayGateway < Gateway
      self.test_url = 'http://200.57.87.243:8855'
      self.live_url = 'https://example.com/live'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['MX']

      self.default_currency = 'MXN'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.netpay.com.mx'

      # The name of the gateway
      self.display_name = 'NETPAY Gateway'

      CURRENCY_CODES = {
        "MXN" => '484'
      }

      RESPONSE_KEYS = ['ResponseMsg', 'ResponseText', 'ResponseCode', 'TimeIn', 'TimeOut', 'AuthCode', 'OrderId', 'CardTypeName', 'MerchantId', 'IssuerAuthDate']

      def initialize(options = {})
        requires!(options, :store_id, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_amount(post, money, options)

        commit('PreAuth', post)
      end

      def cancel(money, authorization, options = {})
        post = {}
        add_order_id(post, authorization)
        add_amount(post, money, options)

        commit('Reverse', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_order_id(post, authorization)
        add_amount(post, money, options)

        commit('PostAuth', post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_amount(post, money, options)

        commit('Auth', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_order_id(post, authorization)
        add_amount(post, money, options)

        commit('Credit', post)
      end


      private

      def add_login_data(post)
        post['StoreId']     = @options[:store_id]
        post['UserName']    = @options[:login]
        post['Password']    = @options[:password]
      end

      def add_action(post, action)
        post['ResourceName'] = action
        post['ContentType']  = 'Transaction'
        post['Mode']         = 'P'
      end

      def add_order_id(post, order_id)
        post['OrderId'] = order_id
      end

      def add_amount(post, money, options)
        post['Total'] = amount(money)
        post['CurrencyCode'] = currency_code(options[:currency] || currency(money))
      end

      def add_customer_data(post, options)
        post['IPAddress'] = options[:ip] unless options[:ip].blank?
      end

      def add_invoice(post, options)
        post['Comments'] = options[:description] if options[:description]
      end

      def add_creditcard(post, creditcard)
        post['CardNumber']   = creditcard.number
        post['ExpDate']      = expdate(creditcard)
        post['CustomerName'] = creditcard.name
        post['CVV2']         = creditcard.verification_value unless creditcard.verification_value.nil?
      end

      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}/#{year[-2..-1]}"
      end

      def url
        test? ? test_url : live_url
      end

      def parse(response)
        params = params_from_response(response)

        success = (params['ResponseCode'] == '00')
        message = params['ResponseText'] || params['ResponseMsg']
        options = @options.merge(:test => test?, :authorization => params['OrderId'])

        Response.new(success, message, params, options)
      end

      def commit(action, parameters)
        add_login_data(parameters)
        add_action(parameters, action)

        post = parameters.collect{|key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        parse ssl_post(url, post)
      end

      # Override the regular handle response so we can access the headers
      def handle_response(response)
        case response.code.to_i
        when 200...300
          response
        else
          raise ResponseError.new(response)
        end
      end

      # Return a hash containing all the useful, or informative values from netpay
      def params_from_response(response)
        params = {}
        RESPONSE_KEYS.each do |k|
          params[k] = response[k] unless response[k].to_s.empty?
        end
        params
      end

      def currency_code(currency)
        return currency if currency =~ /^\d+$/
        CURRENCY_CODES[currency]
      end

    end
  end
end

