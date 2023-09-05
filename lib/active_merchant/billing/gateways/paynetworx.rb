module ActiveMerchant
  module Billing
    class PaynetworxGateway < Gateway

      API_VERSION = '1.0'
      SUCCESS_CODE = %w[00 000 001 002 003 092]
      SOFT_DECLINE_CODES = %w[5 61 65 36 62 75 89 85 80]

      self.test_url = 'https://api.qa.paynetworx.net/v0/transaction/'
      self.live_url = 'https://api.prod.paynetworx.net/v0/transaction/'
      self.default_currency = 'USD'
      self.supported_countries = ['US']
      self.homepage_url = 'https://www.paynetworx.com/'
      self.display_name = 'Paynetworx'

      def initialize(options = {})
        requires!(options, :login, :password, :request_id)
        super
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        add_amount(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_point_of_sale(post, options) if payment_method[:token_id].present?
        commit(post, "auth")
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_amount(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_point_of_sale(post, options) if payment_method[:token_id].present?
        commit(post, "authcapture")
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_amount(post, amount, options)
        add_customer_data(post, options)
        process_payment(post, authorization)
        commit(post, "refund")
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_amount(post, amount, options)
        add_customer_data(post, options)
        process_payment(post, authorization)
        commit(post, "capture")
      end

      def void(authorization, options = {})
        post = {}
        add_customer_data(post, options)
        process_payment(post, authorization)
        void_reasons(post, options)
        commit(post, "void")
      end

      private

      def add_amount(post, amount, options)
        post["Amount"] = {}
        post["Amount"]["Total"] = "%.2f" % amount
        post["Amount"]["Currency"] = options[:currency].present? ? options[:currency] : default_currency
      end

      def add_payment_method(post, payment_method, options)
        post["PaymentMethod"] = {}
        post["PaymentMethod"]["Card"] = {}
        if payment_method[:token_id].present?
          post["PaymentMethod"]["Card"]["CardPresent"] = false
          post["PaymentMethod"]["Token"] = {}
          post["PaymentMethod"]["Token"]["TokenID"] = payment_method[:token_id]
        else
          post["DataAction"] = "token/add"
          post["PaymentMethod"]["Card"]["CardPresent"] = true
          post["PaymentMethod"]["Card"]["CVC"] = {}
          post["PaymentMethod"]["Card"]["CVC"]["CVC"] = payment_method[:cvv]
          post["PaymentMethod"]["Card"]["PAN"] = {}
          post["PaymentMethod"]["Card"]["PAN"]["PAN"] = payment_method[:number]
          post["PaymentMethod"]["Card"]["PAN"]["ExpMonth"] = payment_method[:expiryMonth]
          post["PaymentMethod"]["Card"]["PAN"]["ExpYear"] = payment_method[:expiryYear]
        end
        if options[:billing_address].present?
          post["PaymentMethod"]["Card"]["BillingAddress"] = {}
          post["PaymentMethod"]["Card"]["BillingAddress"]["Name"] = options[:billing_address][:name]
          post["PaymentMethod"]["Card"]["BillingAddress"]["Line1"] = options[:billing_address][:address1]
          post["PaymentMethod"]["Card"]["BillingAddress"]["Line2"] = options[:billing_address][:address2]
          post["PaymentMethod"]["Card"]["BillingAddress"]["City"] = options[:billing_address][:city]
          post["PaymentMethod"]["Card"]["BillingAddress"]["State"] = options[:billing_address][:state]
          post["PaymentMethod"]["Card"]["BillingAddress"]["PostalCode"] = options[:billing_address][:zip]
          post["PaymentMethod"]["Card"]["BillingAddress"]["Country"] = options[:billing_address][:country]
          post["PaymentMethod"]["Card"]["BillingAddress"]["Phone"] = options[:billing_address][:phone]
          post["PaymentMethod"]["Card"]["BillingAddress"]["Email"] = options[:billing_address][:email]
        end
      end

      def add_point_of_sale(post, options)
        post["POS"] = {}
        post["POS"]["EntryMode"] = options[:point_of_sale][:entry_mode]
        post["POS"]["Type"] = options[:point_of_sale][:type]
        post["POS"]["Device"] = options[:point_of_sale][:device]
        post["POS"]["DeviceVersion"] = options[:point_of_sale][:device_version]
        post["POS"]["Application"] = options[:point_of_sale][:application]
        post["POS"]["ApplicationVersion"] = API_VERSION
        post["POS"]["Timestamp"] = formated_timestamp
      end

      def add_customer_data(post, options)
        post["Detail"] = {}
        post["Detail"]["MerchantData"] = {}
        post["Detail"]["MerchantData"]["OrderNumber"] = options[:order_id] if options[:order_id].present?
        post["Detail"]["MerchantData"]["CustomerID"] = options[:customer_id]
      end

      def process_payment(post, authorization)
        post["TransactionID"], = split_authorization(authorization)
      end

      def void_reasons(post, options)
        post["Reason"] = options[:reason] if options[:reason].present?
        post["Detail"]["MerchantData"]["VoidReason"] = options[:void_reason] if options[:void_reason].present?
      end

      def commit(params, action)
        path = "#{url}#{action}"
        url = URI(path)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(url.path, headers)
        request.body = params.to_json
        response = http.request(request)
        response_data = JSON.parse(response.body)
        succeeded = success_from(response_data["ResponseText"])
        Response.new(
          succeeded,
          response_data["ResponseText"],
          response_data,
          authorization: authorization_from(response_data, action),
          test: test?,
          response_type: response_type(response_data["ResponseCode"])
        )
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def success_from(resonse_message)
        resonse_message&.downcase&.include?("approved") ? true : false
      end

      def authorization_from(response, payment_type)
        authorization = response["TransactionID"].present? ? response["TransactionID"] : "Failed"
        [authorization, payment_type].join('#')
      end

      def headers
        headers = {
          'Content-Type' => 'application/json',
          'Request-ID' => @options[:request_id],
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:login]}:#{@options[:password]}")
      end

      def url
        test? ? test_url : live_url
      end

      def response_type(code)
        if SUCCESS_CODE.include?(code)
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end

      def formated_timestamp
        current_time = Time.now.utc
        current_time.strftime("%Y-%m-%dT%H:%M:%S")
      end
    end
  end
end
