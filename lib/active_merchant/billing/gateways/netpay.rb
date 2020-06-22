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
    # Support for calls to the authorize and capture methods have been included
    # as per the Netpay manuals, however, your millage may vary with these
    # methods. At the time of writing (January 2013) they were not fully
    # supported by the production or test gateways. This situation is
    # expected to change within a few weeks/months.
    #
    # Purchases can be cancelled (`#void`) only within 24 hours of the
    # transaction. After this, a refund should be performed instead.
    #
    # In addition to the regular ActiveMerchant transaction options, NETPAY
    # also supports a `:mode` parameter. This allows testing to be performed
    # in production and force specific results.
    #
    #  * 'P' - Production
    #  * 'A' - Approved
    #  * 'D' - Declined
    #  * 'R' - Random (Approved or Declined)
    #  * 'T' - Test
    #
    # For example:
    #
    #     response = @gateway.purchase(1000, card, :mode => 'D')
    #     response.success  # false
    #
    class NetpayGateway < Gateway
      self.test_url = 'http://200.57.87.243:8855'
      self.live_url = 'https://suite.netpay.com.mx/acquirerprd'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['MX']

      self.default_currency = 'MXN'

      # The card types supported by the payment gateway
      self.supported_cardtypes = %i[visa master american_express diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.netpay.com.mx'

      # The name of the gateway
      self.display_name = 'NETPAY Gateway'

      CURRENCY_CODES = {
        'MXN' => '484'
      }

      # The header keys that we will provide in the response params hash
      RESPONSE_KEYS = %w[ResponseMsg ResponseText ResponseCode TimeIn TimeOut AuthCode OrderId CardTypeName MerchantId IssuerAuthDate]

      def initialize(options = {})
        requires!(options, :store_id, :login, :password)
        super
      end

      # Send an authorization request
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_amount(post, money, options)

        commit('PreAuth', post, options)
      end

      # Capture an authorization
      def capture(money, authorization, options = {})
        post = {}
        add_order_id(post, order_id_from(authorization))
        add_amount(post, money, options)

        commit('PostAuth', post, options)
      end

      # Cancel an auth/purchase within first 24 hours
      def void(authorization, options = {})
        post = {}
        order_id, amount, currency = split_authorization(authorization)
        add_order_id(post, order_id)
        post['Total'] = (options[:amount] || amount)
        post['CurrencyCode'] = currency

        commit('Refund', post, options)
      end

      # Make a purchase.
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_amount(post, money, options)

        commit('Auth', post, options)
      end

      # Perform a Credit transaction.
      def refund(money, authorization, options = {})
        post = {}
        add_order_id(post, order_id_from(authorization))
        add_amount(post, money, options)

        commit('Credit', post, options)
      end

      private

      def add_login_data(post)
        post['StoreId']     = @options[:store_id]
        post['UserName']    = @options[:login]
        post['Password']    = @options[:password]
      end

      def add_action(post, action, options)
        post['ResourceName'] = action
        post['ContentType']  = 'Transaction'
        post['Mode']         = options[:mode] || 'P'
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

      def build_authorization(request_params, response_params)
        [response_params['OrderId'], request_params['Total'], request_params['CurrencyCode']].join('|')
      end

      def split_authorization(authorization)
        order_id, amount, currency = authorization.split('|')
        [order_id, amount, currency]
      end

      def order_id_from(authorization)
        split_authorization(authorization).first
      end

      def expdate(credit_card)
        year  = sprintf('%.4i', credit_card.year)
        month = sprintf('%.2i', credit_card.month)

        "#{month}/#{year[-2..-1]}"
      end

      def url
        test? ? test_url : live_url
      end

      def parse(response, request_params)
        response_params = params_from_response(response)

        success = (response_params['ResponseCode'] == '00')
        message = response_params['ResponseText'] || response_params['ResponseMsg']
        options = @options.merge(test: test?,
                                 authorization: build_authorization(request_params, response_params))

        Response.new(success, message, response_params, options)
      end

      def commit(action, parameters, options)
        add_login_data(parameters)
        add_action(parameters, action, options)

        post = parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
        parse(ssl_post(url, post), parameters)
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
