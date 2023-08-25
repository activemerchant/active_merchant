module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FluidpayGateway < Gateway
      include Empty

      SUCCESS_CODE = 100
      SOFT_DECLINE_CODES = [201, 203, 204, 205, 221, 223, 225, 226, 240]

      self.test_url = 'https://sandbox.fluidpay.com'
      self.live_url = 'https://app.fluidpay.com'
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_countries = ['US', 'CA', 'GB', 'AU', 'DE', 'FR', 'ES', 'IT', 'JP', 'SG', 'HK', 'BR', 'MX']
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]
      self.homepage_url = 'https://www.fluidpay.com/'
      self.display_name = 'Fluidpay'

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_level3_fields(post, options)
        add_three_d_secure(post, options)

        commit('transaction', post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_level3_fields(post, options)
        add_reference(post, authorization)

        commit('capture', post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference(post, authorization)

        commit('void', post)
      end

      def refund(amount, authorization, options = {})
        post = {}
        post[:amount] = amount
        add_reference(post, authorization)

        commit('refund', post)
      end

      def verify_credentials
        response = void('0')
        response.message != 'Authentication Failed'
      end

      def supports_network_tokenization?
        true
      end

      def store(payment_method, options = {})
        post = {}
        user_info(post, payment_method, options)
        commit('customer', post)
      end

      private

      def user_info(post, payment_method, options)
        post[:description] = options[:description]
        post[:default_payment] = {}
        post[:default_payment][:card] = {}
        post[:default_payment][:card][:number] = payment_method.number
        post[:default_payment][:card][:expiration_date] = exp_date(payment_method)
        add_customer_data(post, options)
        if post[:billing_address].present?
          post[:default_billing_address] = post[:billing_address]
          post.delete(:billing_address)
        end
        if post[:shipping_address].present?
          post[:default_shipping_address] = post[:shipping_address]
          post.delete(:shipping_address)
        end
      end

      def add_level3_fields(post, options)
        add_fields_to_post_if_present(post, options, %i[tax_amount shipping_amount po_number])
      end

      def add_invoice(post, money, options)
        post[:type] = options[:type]
        post[:amount] = money
        post[:order_id] = options[:order_id]
        post[:description] = options[:description]
        post[:currency] = options[:currency] || currency(money)
        post[:billing_method] = 'recurring' if options[:recurring]
      end

      def add_payment_method(post, payment_method, options)
        post[:payment_method] = {}
        post[:payment_method][:card] = {}

        if payment_method.is_a?(NetworkTokenizationCreditCard)
          post[:payment_method][:card][:number] = payment_method.number
          post[:payment_method][:card][:expiration_date] = exp_date(payment_method)
          post[:payment_method][:card][:token_cryptogram] = payment_method.payment_cryptogram
        elsif card_brand(payment_method) == 'check'
          post[:payment] = 'check'
          post[:payment_method][:ach][:account_number] = payment_method.account_number
          post[:payment_method][:ach][:routing_number] = payment_method.routing_number
          post[:payment_method][:ach][:check_number] = payment_method.check_number
          post[:payment_method][:ach][:account_holder_type] = payment_method.account_holder_type
          post[:payment_method][:ach][:account_type] = payment_method.account_type
          post[:payment_method][:ach][:sec_code] = options[:sec_code] || 'WEB'
        else
          post[:payment] = 'credit_card'
          post[:payment_method][:card][:number] = payment_method.number
          post[:payment_method][:card][:cvc] = payment_method.verification_value unless empty?(payment_method.verification_value)
          post[:payment_method][:card][:expiration_date] = exp_date(payment_method)
        end
      end

      def add_customer_data(post, options)
        if (billing_address = options[:billing_address] || options[:address])
          post[:billing_address] = {}
          post[:billing_address][:first_name] = billing_address[:firstname]
          post[:billing_address][:last_name] = billing_address[:lastname]
          post[:billing_address][:company] = billing_address[:company]
          post[:billing_address][:address_line_1] = billing_address[:address1]
          post[:billing_address][:city] = billing_address[:city]
          post[:billing_address][:state] = billing_address[:state]
          post[:billing_address][:country] = billing_address[:country]
          post[:billing_address][:postal_code] = billing_address[:zip]
          post[:billing_address][:phone] = billing_address[:phone]
          post[:billing_address][:email] = billing_address[:email]
        end

        if (shipping_address = options[:shipping_address])
          post[:shipping_address] = {}
          post[:shipping_address][:first_name] = shipping_address[:firstname]
          post[:shipping_address][:last_name] = shipping_address[:lastname]
          post[:shipping_address][:company] = shipping_address[:company]
          post[:shipping_address][:address_line_1] = shipping_address[:address1]
          post[:shipping_address][:city] = shipping_address[:city]
          post[:shipping_address][:state] = shipping_address[:state]
          post[:shipping_address][:country] = shipping_address[:country]
          post[:shipping_address][:postal_code] = shipping_address[:zip]
          post[:shipping_address][:phone] = shipping_address[:phone]
          post[:shipping_address][:email] = shipping_address[:email]
        end

        if (descriptor = options[:descriptors])
          post[:descriptor] = {}
          post[:descriptor][:name] = descriptor[:name]
          post[:descriptor][:address] = descriptor[:address]
          post[:descriptor][:city] = descriptor[:city]
          post[:descriptor][:state] = descriptor[:state]
          post[:descriptor][:postal_code] = descriptor[:postal_code]
        end
      end

      def add_vendor_data(post, options)
        post[:vendor_id] = options[:vendor_id] if options[:vendor_id]
        post[:processor_id] = options[:processor_id] if options[:processor_id]
      end

      def add_three_d_secure(post, options)
        three_d_secure = options[:three_d_secure]
        return unless three_d_secure

        post[:payment_method] = {}
        post[:payment_method][:card] = {}
        post[:payment_method][:card][:cardholder_authentication] = {}
        post[:payment_method][:card][:cardholder_authentication][:cavv] = three_d_secure[:cavv]
        post[:payment_method][:card][:cardholder_authentication][:xid] = three_d_secure[:xid]
        post[:payment_method][:card][:cardholder_authentication][:version] = three_d_secure[:version]
        post[:payment_method][:card][:cardholder_authentication][:eci] = three_d_secure[:eci]
        post[:payment_method][:card][:cardholder_authentication][:ds_transaction_id] = three_d_secure[:ds_transaction_id]
        post[:payment_method][:card][:cardholder_authentication][:acs_transaction_id] = three_d_secure[:acs_transaction_id]
      end

      def add_reference(post, authorization)
        transaction_id, = split_authorization(authorization)[0]
        post[:transactionid] = transaction_id
      end

      def exp_date(payment_method)
        "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
      end

      def commit(action, params)
        request_url = action == "customer" ? "#{url}/api/vault/customer" : "#{url}/api/transaction"
        request_url = (request_url + "/" + params[:transactionid] + "/" + action) if params[:transactionid].present?
        raw_response = ssl_post(request_url, params.to_json, headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response, params[:payment], action),
          avs_result: AVSResult.new(code: response.dig('data', 'response_body', 'card', 'avs_response_code')),
          cvv_result: CVVResult.new(response.dig('data', 'response_body', 'card', 'avs_response_code')),
          test: test?,
          response_type: response_type(response.dig('data', 'response_code'))
        )
      end

      def authorization_from(response, payment_type, action)
        authorization = response.dig('data', 'id')
        [authorization, payment_type].join('#')
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def headers
        headers = { 'Content-Type' => 'application/json', 'Authorization' => @options[:api_key] }
        headers
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response["msg"] == "success"
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response["msg"]
        end
      end

      def response_type(code)
        if code == SUCCESS_CODE
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end
    end
  end
end
