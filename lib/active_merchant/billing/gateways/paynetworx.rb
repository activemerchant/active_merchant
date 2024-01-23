module ActiveMerchant
  module Billing
    class PaynetworxGateway < Gateway
      include Empty

      API_VERSION = '1.0'
      SUCCESS_CODE = %w[00 000 001 002 003 092]
      SOFT_DECLINE_CODES = %w[5 61 65 36 62 75 89 85 80]

      self.test_url = 'https://api.qa.paynetworx.net/v0/transaction/'
      self.live_url = 'https://api.prod.paynetworx.net/v0/transaction/'
      self.default_currency = 'USD'
      self.supported_countries = ['US']
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'https://www.paynetworx.com/'
      self.display_name = 'Paynetworx'

      def initialize(options = {})
        requires!(options, :login, :password, :request_id)
        super
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_transaction_descriptor(post, options)
        add_point_of_sale(post, options) if payment_method.is_a?(String)
        commit(post, 'auth')
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_transaction_descriptor(post, options)
        add_point_of_sale(post, options) if payment_method.is_a?(String)
        commit(post, 'authcapture')
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        process_payment(post, authorization)
        commit(post, 'refund')
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        process_payment(post, authorization)
        commit(post, 'capture')
      end

      def void(authorization, options = {})
        post = {}
        add_customer_data(post, options)
        process_payment(post, authorization)
        void_reasons(post, options)
        commit(post, 'void')
      end

      private

      def add_invoice(post, amount, options)
        post['Amount'] = {}
        post['Amount']['Total'] = localized_amount(amount, options[:currency])
        post['Amount']['Currency'] = options[:currency] || currency(amount)
      end

      def add_payment_method(post, payment_method, options)
        post['PaymentMethod'] = { 'Card' => {} }

        if payment_method.is_a?(String)
          post['PaymentMethod']['Card']['CardPresent'] = false
          post['PaymentMethod']['Token'] = { 'TokenID' => payment_method }
        else
          post['DataAction'] = 'token/add'
          post['PaymentMethod']['Card']['CardPresent'] = true
          card_info = post['PaymentMethod']['Card']

          card_info['CVC'] = { 'CVC' => payment_method.verification_value } unless empty?(payment_method.verification_value)
          card_info['PAN'] = {
            'PAN' => payment_method.number,
            'ExpMonth' => format(payment_method.month, :two_digits),
            'ExpYear' => format(payment_method.year, :two_digits)
          }
        end

        card_info = post['PaymentMethod']['Card']

        if options[:billing_address].present?
          billing_address = options[:billing_address]
          card_info['BillingAddress'] = {
            'Name' => billing_address[:name],
            'Line1' => billing_address[:address1],
            'Line2' => billing_address[:address2],
            'City' => billing_address[:city],
            'State' => billing_address[:state],
            'PostalCode' => billing_address[:zip],
            'Country' => billing_address[:country],
            'Phone' => billing_address[:phone],
            'Email' => options[:email]
          }
        end

        if options[:three_d_secure].present?
          secure_info = card_info['3DSecure'] = {}
          secure_info['AuthenticationValue'] = options[:three_d_secure][:splitSdkServerTransId]
          secure_info['ECommerceIndicator'] = options[:three_d_secure][:eci]
          secure_info['3DSecureTransactionID'] = options[:three_d_secure][:authenticationValue]
        end
      end

      def add_point_of_sale(post, options)
        post['POS'] = {}
        post['POS']['EntryMode'] = 'card-on-file'
        post['POS']['Type'] = 'recurring'
        post['POS']['Device'] = 'NA'
        post['POS']['DeviceVersion'] = 'NA'
        post['POS']['Application'] = 'Swiss CRM'
        post['POS']['ApplicationVersion'] = API_VERSION
        post['POS']['Timestamp'] = formated_timestamp
      end

      def add_customer_data(post, options)
        post['Detail'] = {}
        post['Detail']['MerchantData'] = {}
        post['Detail']['MerchantData']['OrderNumber'] = options[:order_id]
        post['Detail']['MerchantData']['CustomerID'] = options[:customer_id]
      end

      def add_transaction_descriptor(post, options)
        return unless options[:descriptor]

        post['Attributes'] = {}
        post['Attributes']['TransactionDescriptor'] = {}
        post['Attributes']['TransactionDescriptor']['Prefix'] = split_descriptor(options[:descriptor])
      end

      def process_payment(post, authorization)
        post['TransactionID'], = split_authorization(authorization)
      end

      def void_reasons(post, options)
        post['Reason'] = options[:reason] if options[:reason].present?
        post['Detail']['MerchantData']['VoidReason'] = options[:void_reason] if options[:void_reason].present?
      end

      def commit(params, action)
        request_body = params.to_json
        request_endpoint = "#{url}#{action}"
        response = ssl_post(request_endpoint, request_body, headers)
        response_data = JSON.parse(response)
        succeeded = success_from(response_data['ResponseText'])
        Response.new(
          succeeded,
          response_data['ResponseText'],
          response_data,
          authorization: authorization_from(response_data, action),
          test: test?,
          response_type: response_type(response_data['ResponseCode']),
          response_http_code: @response_http_code,
          request_endpoint: request_endpoint,
          request_method: :post,
          request_body: request_body
        )
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def split_descriptor(descriptor)
        descriptor.split('*')[0]
      end

      def success_from(resonse_message)
        resonse_message&.downcase&.include?('approved') ? true : false
      end

      def authorization_from(response, payment_type)
        authorization = response['TransactionID'].present? ? response['TransactionID'] : 'Failed'
        [authorization, payment_type].join('#')
      end

      def headers
        {
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
        current_time.strftime('%Y-%m-%dT%H:%M:%S')
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        response.body
      end
    end
  end
end
