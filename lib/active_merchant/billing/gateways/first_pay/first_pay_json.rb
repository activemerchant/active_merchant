require 'active_merchant/billing/gateways/first_pay/first_pay_common'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class FirstPayJsonGateway < Gateway
      include FirstPayCommon

      ACTIONS = {
        purchase: 'Sale',
        authorize: 'Auth',
        capture: 'Settle',
        refund: 'Refund',
        void: 'Void'
      }.freeze

      WALLET_TYPES = {
        apple_pay: 'ApplePay',
        google_pay: 'GooglePay'
      }.freeze

      self.test_url = 'https://secure-v.1stPaygateway.net/secure/RestGW/Gateway/Transaction/'
      self.live_url = 'https://secure.1stPaygateway.net/secure/RestGW/Gateway/Transaction/'

      # Creates a new FirstPayJsonGateway
      #
      # The gateway requires two values for connection to be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:merchant_key</tt>  -- FirstPay's merchant_key (REQUIRED)
      # * <tt>:processor_id</tt>  -- FirstPay's processor_id or processorId (REQUIRED)
      def initialize(options = {})
        requires!(options, :merchant_key, :processor_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)

        commit(:purchase, post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)

        commit(:authorize, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)
        add_reference(post, authorization)

        commit(:capture, post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)
        add_reference(post, authorization)

        commit(:refund, post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference(post, authorization)

        commit(:void, post)
      end

      def scrub(transcript)
        transcript.
          gsub(%r(("processorId\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("merchantKey\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cardNumber\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("paymentCryptogram\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\?"\s*:\s*\\?)[^,]*)i, '\1[FILTERED]')
      end

      private

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:ownerName] = address[:name]
          post[:ownerStreet] = address[:address1]
          post[:ownerCity] = address[:city]
          post[:ownerState] = address[:state]
          post[:ownerZip] = address[:zip]
          post[:ownerCountry] = address[:country]
        end
      end

      def add_invoice(post, money, options)
        post[:orderId] = options[:order_id]
        post[:transactionAmount] = amount(money)
      end

      def add_payment(post, payment, options)
        post[:cardNumber] = payment.number
        post[:cardExpMonth] = payment.month
        post[:cardExpYear] = format(payment.year, :two_digits)
        post[:cvv] = payment.verification_value
        post[:recurring] = options[:recurring] if options[:recurring]
        post[:recurringStartDate] = options[:recurring_start_date] if options[:recurring_start_date]
        post[:recurringEndDate] = options[:recurring_end_date] if options[:recurring_end_date]

        case payment
        when NetworkTokenizationCreditCard
          post[:walletType] = WALLET_TYPES[payment.source]
          other_fields = post[:otherFields] = {}
          other_fields[:paymentCryptogram] = payment.payment_cryptogram
          other_fields[:eciIndicator] = payment.eci || '07'
        when CreditCard
          post[:cvv] = payment.verification_value
        end
      end

      def add_reference(post, authorization)
        post[:refNumber] = authorization
      end

      def commit(action, parameters)
        response = parse(api_request(base_url + ACTIONS[action], post_data(parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(response),
          test: test?
        )
      end

      def base_url
        test? ? self.test_url : self.live_url
      end

      def api_request(url, data)
        ssl_post(url, data, headers)
      rescue ResponseError => e
        e.response.body
      end

      def parse(data)
        JSON.parse data
      end

      def headers
        { 'Content-Type' => 'application/json' }
      end

      def format_messages(messages)
        return unless messages.present?

        messages.map { |message| message['message'] || message }.join('; ')
      end

      def success_from(response)
        response['isSuccess']
      end

      def message_from(response)
        format_messages(response['errorMessages'] + response['validationFailures']) || response['data']['authResponse']
      end

      def error_code_from(response)
        return 'isError' if response['isError']

        return 'validationHasFailed' if response['validationHasFailed']
      end

      def authorization_from(response)
        response.dig('data', 'referenceNumber') || ''
      end

      def post_data(params)
        params.merge({ processorId: @options[:processor_id], merchantKey: @options[:merchant_key] }).to_json
      end
    end
  end
end
