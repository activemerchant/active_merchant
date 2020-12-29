module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class UnipaasGateway < Gateway
      self.test_url = 'https://sandbox.unipaas.com/api'
      self.live_url = 'https://api.unipaas.com/api'

      self.supported_countries = %w[AT BE BG CY CZ DE DK EE GR ES FI FR GI HK HR HU IE IS IT LI LT LU LV MT MX NL NO PL PT RO SE SG SI SK GB US]
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://www.unipaas.com/'
      self.display_name = 'UNIPaaS Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        add_customer_data(post, options)
        post[:transactionType] = 'Sale'

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        add_customer_data(post, options)
        post[:transactionType] = 'Auth'

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)
        commit('capture', post, authorization)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)
        commit('refund', post, authorization)
      end

      def void(authorization, options = {})
        post = {}
        commit('void', post, authorization)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment, options = {})
        post = {}
        post[:number] = payment.number
        post[:securityCode] = payment.verification_value
        post[:expMonth] = payment.month
        post[:expYear] = payment.year
        post[:nameOnCard] = "#{payment.first_name} #{payment.last_name}"
        add_customer_data(post, options)

        commit('store', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
            gsub(%r((\\?"number\\?":\\?")[^\\"]+(\\?"))i, '\1[FILTERED]\2').
            gsub(%r((\\?"securityCode\\?":\\?")[^\\"]+(\\?"))i, '\1[FILTERED]\2').
            gsub(%r((Authorization: Bearer )\w+)i, '\1[FILTERED]\2')
      end

      private

      def add_customer_data(post, options)
        post[:consumer] = {}
        post[:consumer][:email] = options[:email] if options[:email]
        post[:consumer][:shippingAddress] = {}
        billing_address = (options[:billing_address] || options[:address])
        post[:consumer][:shippingAddress][:country] = billing_address[:country] if billing_address && billing_address[:country]
        post[:deviceDetails] = {} if options[:ip]
        post[:deviceDetails][:ipAddress] = options[:ip] if options[:ip]
      end

      def add_address(post, creditcard, options) end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:orderid] = options[:order_id] if options[:order_id]
      end

      def add_payment(post, payment, options)
        if payment.is_a?(String)
          post[:payment_option_id] = payment
        else
          post[:paymentOption] = {}
          post[:paymentOption][:number] = payment.number
          post[:paymentOption][:securityCode] = payment.verification_value
          post[:paymentOption][:expMonth] = payment.month
          post[:paymentOption][:expYear] = payment.year
          post[:paymentOption][:nameOnCard] = "#{payment.first_name} #{payment.last_name}"
        end

        if options[:is_recurring] || options[:initial_transaction_id]
          post[:recurring] = {}
          post[:recurring][:is_recurring] = options[:is_recurring] if options[:is_recurring]
          post[:recurring][:initial_transaction_id] = options[:initial_transaction_id] if options[:initial_transaction_id]
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, authorization = nil)
        response = parse(ssl_post(url(action, authorization), post_data(action, parameters), headers))

        Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            avs_result: AVSResult.new(code: response["some_avs_response_key"]),
            cvv_result: CVVResult.new(response["some_cvv_response_key"]),
            test: test?,
            error_code: error_code_from(response)
        )
      end

      def url(action, authorization)
        base_url = (test? ? test_url : live_url)
        case action
        when 'sale'
          "#{base_url}/Authorization/"
        when 'authonly'
          "#{base_url}/Authorization/"
        when 'capture'
          "#{base_url}/Authorization/#{authorization}/Settle"
        when 'refund'
          "#{base_url}/Authorization/#{authorization}/Refund"
        when 'void'
          "#{base_url}/Authorization/#{authorization}/Void"
        when 'store'
          "#{base_url}/Payment_Option/Card"
        else
          "Error: action has an invalid value (#{action})"
        end
      end

      def success_from(response)
        if response['data']['status']
          (response['data']['status'] === 'Approved')
        else #token
          (response['status'] === 201)
        end
      end

      def message_from(response)
        if response['data']['status']
          return response['data']['data']['error'] if response['data']['status'] == 500

          (response['data']['status'] != 'Approved' ? response['data']['processor']['processorDescription'] : 'Success')
        else #token
          (response['status'] === 201 ? 'Success' : 'Failed')
        end
      end

      def authorization_from(response)
        response['data']['authorizationId'] || response['data']['payment_option_id']
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          response['status']
        end
      end

      def headers
        {
            'Content-type' => 'application/json',
            'Authorization' => "Bearer #{@options[:private_key]}"
        }
      end
    end
  end
end