module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BanwireGateway < Gateway
      self.test_url = 'https://test.banwire.com/sw/?action=active_merchant&sandbox=qa'
      self.live_url = 'https://sw.banwire.com/sw/?action=active_merchant'

      self.supported_countries = ['MX']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.banwire.com/'
      self.display_name = 'Banwire'
      self.money_format = :dollars
      self.default_currency = 'MXN'

      def initialize(options={})
        requires!(options, :login)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_response_type(post)
        add_order_data(post, money, options)
        add_special_data(post,options)
        add_customer_data(post, options)
        add_shipment_address(post, options)
        add_payment(post, payment, options)

        commit('&payment=direct', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_response_type(post)
        add_order_data(post, money, options)
        add_special_data(post,options)
        add_customer_data(post, options)
        add_shipment_address(post, options)
        add_payment(post, payment, options)

        commit('&payment=direct', post)
      end

      def refund(money, identifier, options={})
        post = {}
        post[:id] = identifier
        add_auth_data(post, options)

        commit('&payment=transaction_back', post)
      end

      private

      def add_response_type(post)
        post[:response_format] = "JSON"
      end

      def add_auth_data(post, options)
        post[:user] = @options[:login] if @options[:login] #- User (required) [alphanumeric] (Test: userdemo)
      end

      def add_order_data(post, money, options)
        post[:ORD_CURR_CD] = (options[:currency] || currency(money)).upcase #- Currency (optional) [text - length: 3] (Default: MXN)
        post[:ORD_ID] = options[:order_id] #- Unique transaction ID (required) [alphanumeric - length: 1-22] (Example: 12345ABC)
        post[:ORD_AMT] = amount(money) #- Transaction amount (required) [float - length: 10,2] (Example: 100.00)
        post[:ORD_CONCEPT] = options[:description] #- Concept (optional) [alphanumeric - lenght: 1-33] (Example: Compra de articulos)
      end

      def add_special_data(post, options)
        post[:EBT_PREVCUST] = "N" #- Regular customer (required) [text - length: 1] (Y=Yes, N=No) (Default: N)
        post[:EBT_DEVICEPRINT] = options[:device_print] if options[:device_print] #- Device print (optional) [text - lenght: 1-4000]
        post[:CUST_IP] = options[:ip] if options[:ip] #- IP address of customer (optional) [text - lenght: 255] (Example: 127.0.0.1)
        post[:ebWEBSITE] = options[:web_site] if options[:web_site] #- URL website (optional) [text - lenght: 1-60] (Example: www.comercio.com)
        post[:PROD_DEL_CD] = options[:prod] || "DNP" #- Product type (required) [text - lenght: 3] [CNC=buy and ship, DCT=digital contents, DIG=digital goods, DNP=physical and digital, GFT=gift certificate, PHY=physical goods, REN=renewals and recharges, SVC=services] (Default: DNP) 
        post[:NOTIFY_URL] = options[:notify_url] if options[:notify_url] #- Notify URL (optional) [text - lenght: 255] (Example: www.comercio.com/response.php)

        add_auth_data(post, options)
      end

      def add_customer_data(post, options)
        address = options[:address] || options[:billing_address]
        post[:CUST_USER_ID] = options[:cust_id] if options[:cust_id] #- Customer ID (required) [alphanumeric - lenght: 1-16] (Example: carlos)
        post[:CUST_PHONE] = options[:phone] #- Phone customer (required) [numeric - lenght: 5-15] (Example: 2234567890)
        post[:CUST_EMAIL] = options[:email] #- Email customer (required) [alphanumeric - lenght: 1-60] (Example: user@customer.com)
        post[:CUST_FNAME] = options[:name] if options[:name] #- First name customer (required) [text - lenght: 1-30] (Example: Carlos)
        post[:CUST_MNAME] = options[:middle_name] if options[:middle_name] #- Middle name customer (required) [text - lenght: 1-30] (Example: Garcia)
        post[:CUST_LNAME] = options[:last_name] if options[:last_name] #- Last name customer (required) [text - lenght: 1-30] (Example: Valles)

        post[:CUST_HOME_PHONE] = options[:home_phone] if options[:home_phone] #- Home phone customer (required) [numeric - lenght: 5-19] (Example: 2234567890)
        post[:CUST_WORK_PHONE] = options[:work_phone] if options[:work_phone] #- Work phone customer (optional) [numeric - length: 5-19] (Example: 3345678901)

        post[:CUST_ADDR1] = address[:address] if address[:address] #- Address customer (required) [alphanumeric - lenght: 1-30] (Example: La esperanza 14)
        post[:CUST_CITY] = address[:city] if address[:city] #- City address customer (required) [text - lenght: 1-20] (Example: Mexico)
        post[:CUST_STPR_CD] = address[:state] if address[:state] #- State address customer (required) [text - lenght: 2] (ISO 3166-2) (Example: DF)
        post[:CUST_POSTAL_CD] = address[:zip] if address[:zip] #- Zip address customer (required) [alphanumeric - lenght: 5-7] (Example: 54321)
        post[:CUST_CNTRY_CD] = address[:contry] if address[:contry] #- Country address customer (required) [text - lenght: 3] (ISO 3166-1) (Example: MX)
      end

      def add_shipment_address(post, options)
        address = options[:shipping_address] || {}

        post[:SHIP_ID] = address[:id] if address[:id] #- Shipping address reference ID (optional) [text - lenght: 1-16] (Example: 15473sa)
        post[:SHIP_HOME_PHONE] = address[:phone] if address[:phone] #- Phone shipping address (optional) [text - lenght: 5-19] (Example: 2234567890)
        post[:SHIP_EMAIL] = address[:email] if address[:email] #- Email customer (optional) [alphanumeric - lenght: 1-60] (Example: user@customer.com)
        post[:SHIP_FNAME] = address[:name] if address[:name] #- First name (optional) [text - lenght: 1-30] (Example: Carlos)
        post[:SHIP_MNAME] = address[:middle_name] if address[:middle_name] #- Middle name (optional) [text - lenght: 1-30] (Example: Garcia)
        post[:SHIP_LNAME] = address[:last_name] if address[:last_name] #- Last name (optional) [text - lenght: 1-30] (Example: Valles) 
        post[:SHIP_MTHD_CD] = address[:method] if address[:method] #- Shipping method (optional) [text - lenght: 1] [C=low cost, D=own shipping method, I=international, M=military, N=next day, O=others, P=store pickup, T=2 day shipping, W=3 day shipping] (Example: D)
        post[:SHIP_ADDR1] = address[:address] if address[:address] #- Shipping address (optional) [alphanumeric - lenght: 1-30] (Example: La esperanza 14)
        post[:SHIP_CITY] = address[:city] if address[:city] #- City shipping address (optional) [text - lenght: 1-20] (Example: Mexico)
        post[:SHIP_STPR_CD] = address[:state] if address[:state] #- State shipping address (optional) [text - lenght: 2] (ISO 3166-2) (Example: DF)
        post[:SHIP_POSTAL_CD] = address[:zip] if address[:zip] #- Zip shipping address (optional) [alphanumeric - lenght: 1-10] (Example: 54321)
        post[:SHIP_CNTRY_CD] = address[:contry] if address[:contry] #- Country shipping address (optional) [text - lenght: 3] (ISO 3166-1) (Example: MX)
      end

      def add_address(post, options)
        address = options[:billing_address] || {}

        post[:CARD_AVS_ADDR] = address[:address] if address[:address] #- Billing address (required) [alphanumeric - lenght: 1-30] (Example: La esperanza 14)
        post[:CARD_AVS_ZIPCODE] = address[:zip] if address[:zip] #- Zip billing address (required) [alphanumeric - lenght: 5-7] (Example: 54321)
      end

      def add_payment(post, payment, options)
        post[:CARD_NUM] = payment.number #- Card number (required) [numeric - lenght: 15-16] (Example: 5134422031476272)
        post[:CARD_OWN] = payment.name #- Card owner name (required) [text - lenght: 1-30] (Example: Carlos Garcia Valles)
        post[:CARD_EXP_DT] = sprintf("%02d", payment.month)+payment.year.to_s[-2,2] #- Card expiration date (required) [text - lenght: 4] [Format:MMYY] (Example: 1219)
        post[:CARD_CVV] = payment.verification_value #- Card CVV (required) [text - lenght: 3-4] (Example: 162)
        post[:CARD_TYPE] = card_brand(payment) #- Card type (required) [text - lenght:4-10] (Example: MASTERCARD)

        add_address(post, options)
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def commit(url_action, parameters)
        success = false
        message = ""
        url = (test? ? test_url : live_url) + url_action
        raw_response = ssl_post(url, post_data(parameters))
        begin
          response = parse(raw_response)
          success = (response["ID"] && response["AUTH_CODE"]) || (response["folio"] && response["status"] == "ok")
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        if success 
          message = "success"
        else
          message = response["ERROR_MSG"] || ""
        end

        Response.new(success, message, response,
	  :test => test?,
	  :authorization => authorization_from(response),
	  :fraud_review => fraud_review?(response)
	)
      end

      def fraud_review?(response)
        response["ERROR_CODE"] && response["ERROR_CODE"] == "500"
      end

      def authorization_from(response)
        response["AUTH_CODE"] || response["folio"] || ""
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Banwire API.  Please contact Banwire support if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "ERROR_MSG" => msg
        }
      end

    end
  end
end
