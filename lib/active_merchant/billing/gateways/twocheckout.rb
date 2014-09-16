module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on using the 2Checkout API, please visit their {Documentation}[https://www.2checkout.com/documentation/]
    #
    # Instantiate a instance of TwocheckoutGateway by passing through your Seller ID and API Key.
    #
    # ==== To obtain your test API key
    #
    # 1. Signup for a sandbox account https://sandbox.2checkout.com/sandbox/
    # 2. Click the "API" tab
    # 3. Read the agreement and continue to access your keys
    #
    class TwocheckoutGateway < Gateway
      self.test_url = 'https://sandbox.2checkout.com/checkout/api/1/'
      self.live_url = 'https://www.2checkout.com/checkout/api/1/'

      self.supported_countries = %w(AF AL DZ AS AD AO AI AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ
      BJ BM BT BO BA BW BV BR IO BN BG BF BI KH CM CA CV KY CF TD CL CN CX CC CO KM CG CD CK CR CI
      HR CW CY CZ DK DJ DM DO EC EG SV GQ ER EE ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL
      GD GP GU GT GG GN GW GY HT HM VA HN HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI KR
      KV KW KG LA LV LB LS LR LY LI LT LU MO MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME
      MS MA MZ MM NA NR NP NL AN NC NZ NI NE NG NU NF MP NO OM PK PW PS PA PG PY PE PH PN PL PT PR
      QA RE RO RU RW BL SH KN LC MF PM VC WS SM ST SA SN RS SC SL SG SK SI SB SO ZA GS ES LK SR SJ
      SZ SE CH TW TJ TZ TH TL TG TK TO TT TN TR TM TC TV UG UA AE GB US UM UY UZ VU VE VN VG VI WF
      EH YE ZM ZW AX)

      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.homepage_url = 'https://www.2checkout.com'
      self.display_name = '2Checkout'

      # Creates a new TwocheckoutGateway
      #
      # ==== Options
      #
      # * <tt>:login</tt>     -- 2Checkout Seller ID (REQUIRED)
      # * <tt>:api_key</tt>   -- 2Checkout API Private Key (REQUIRED)
      #
      def initialize(options = {})
        requires!(options, :login, :api_key)
        @seller_id = options[:login]
        @private_key = options[:api_key]
        super
      end

      # Creates a new TwocheckoutGateway
      #
      # * <tt>:amount</tt>    -- Amount in cents (REQUIRED)
      # * <tt>:token</tt>     -- Credit Card Token (REQUIRED)
      # -  This token is obtained using the 2co.js JavaScript library.
      # -  Example: http://jsbin.com/mibojono/13/edit?html,output
      #
      # ==== Options
      #
      # * <tt>:order_id</tt>          -- Custom Order Identifier (REQUIRED)
      # * <tt>:email</tt>             -- Customer Email (REQUIRED)
      # * <tt>:currency</tt>          -- Customer Currency Code (REQUIRED)
      # * <tt>:billing_address</tt>   -- Customer Billing Address (REQUIRED)
      # * <tt>:shipping_address</tt>  -- Customer Billing Address (OPTIONAL)
      # * <tt>:items</tt>             -- Customer Billing Address (OPTIONAL)
      # ==== Items
      # * Lineitem parameters can be found in {2Checkout's Documentation}[https://www.2checkout.com/documentation/payment-api/create-sale]
      # - Passing in :items will override the amount and calculate the total at a lineitem level.
      #   Example:
      #   options[:items] = [
      #      {
      #        name: 'Example Lineitem',
      #        price: 250,
      #        quantity: 2,
      #        options: [
      #          {
      #            name: 'color',
      #            value: 'red',
      #            price: 100
      #          },
      #          {
      #            name: 'size',
      #            value: 'XL',
      #            price: 300
      #          }
      #        ]
      #      },
      #      {
      #        name: 'Example Lineitem',
      #        price: 200,
      #        quantity: 1,
      #        recurrence: '1 Month',
      #        duration: 'Forever'
      #      }
      #   ]
      #   
      def purchase(money, token, options = {})
        requires!(options, :order_id)
        authorize(money, token, options.merge(commit: true))
      end

      def authorize(money, token, options = {})
        args = setup_auth_args(money, token, options)
        commit(:post, "#{@seller_id}/rs/authService", args)
      end

      private

      def setup_auth_args(money, token, options)
        post = {}
        currency = options[:currency] || default_currency
        post[:currency] = currency.upcase

        if options[:items]
          add_lineitems(post, currency, options)
        else
          add_total(post, money, currency)
        end

        add_customer(post, options)
        post[:token] = token
        post[:sellerId] = @seller_id
        post[:privateKey] = @private_key
        post[:merchantOrderId] = options[:order_id]
        post.to_json
      end

      def add_total(post, money, currency)
        currency = options[:currency] || default_currency
        post[:total] = localized_amount(money, currency)
      end

      def add_lineitems(post, currency, options)
        requires!(options, :items)
        post[:lineItems] = []
        if options[:items].length > 0
          options[:items].each do |item|
            requires!(item, :name, :quantity, :price)
            item[:price] = localized_amount(item[:price], currency)
            if item[:options] && item[:options].length > 0
              item[:options].each do |option|
                requires!(option, :name, :value, :price)
                option[:optName] = option.delete :name
                option[:optValue] = option.delete :value
                option[:optSurcharge] = localized_amount(option[:price], currency)
                option.delete :price
              end
            end
            post[:lineItems] << item
          end
        else
          raise ArgumentError.new('Must include at least 1 item when passing :items')
        end
      end

      def add_customer(post, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || nil
        raise ArgumentError.new('Options must include :billing_address or :address') if billing_address.nil?
        requires!(billing_address, :name, :address1, :city, :country)

        billing_hash = {}
        billing_hash[:email] = options[:email]
        billing_hash[:phoneNumber] = billing_address[:phone]
        billing_hash[:name] = billing_address[:name]
        billing_hash[:addrLine1] = billing_address[:address1]
        billing_hash[:addrLine2] = billing_address[:address2] if billing_address[:address2]
        billing_hash[:city] = billing_address[:city]
        billing_hash[:state] = billing_address[:state] if billing_address[:state]
        billing_hash[:zipCode] = billing_address[:zip] if billing_address[:zip]
        billing_hash[:country] = billing_address[:country]
        post[:billingAddr] = billing_hash

        if shipping_address
          requires!(shipping_address, :name, :address1, :city, :country)
          shipping_hash = {}
          shipping_hash[:name] = shipping_address[:name]
          shipping_hash[:addrLine1] = shipping_address[:address1]
          shipping_hash[:addrLine2] = shipping_address[:address2] if shipping_address[:address2]
          shipping_hash[:city] = shipping_address[:city]
          shipping_hash[:state] = shipping_address[:state] if shipping_address[:state]
          shipping_hash[:zipCode] = shipping_address[:zip] if shipping_address[:zip]
          shipping_hash[:country] = shipping_address[:country]
          post[:shippingAddr] = shipping_hash
        end
      end

      def headers(_options = {})
        headers = {
          'Content-Type'  => 'application/json',
          'User-Agent' => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
        headers
      end

      def commit(method, path, parameters = nil, options = {})
        base = test? ? test_url : live_url
        success = false
        begin
          raw_response = ssl_request(method, base + path, parameters, headers(options))
          response = parse(raw_response)
          success = response['exception'].nil?
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        Response.new(success,
                     success ? 'Transaction approved' : response['exception']['errorMsg'],
                     response,
                     test: test?,
                     authorization: success ? response['response']['orderNumber'] : response['exception']['errorCode']
        )
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = "Invalid response from 2Checkout: Received: #{raw_response.inspect})"
        {
          'error' => [{
            'message' => msg
          }]
        }
      end
    end
  end
end
