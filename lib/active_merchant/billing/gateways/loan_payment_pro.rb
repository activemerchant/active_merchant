module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class LoanPaymentProGateway < Gateway
      self.live_url = 'https://gateway.loanpaymentpro.com'
      self.test_url = 'https://gateway.loanpaymentpro.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://loanpaymentpro.com/'
      self.display_name = 'LoanPaymentPro'

      RESPONSE_CODE_MAPPING = {
        1 => 'Customer added successfully.',
        3 => 'Customer removed successfully.',
        4 => 'An error occurred while removing the customer.',
        5 => 'Customer updated successfully.',
        6 => 'An error occurred while updating the customer.',
        7 => 'Customer was retrieved successfully.',
        8 => 'A customer with that token was not found.',
        9 => 'Customer listing successful.',
        10 => 'Payment method was removed successfully.',
        11 => 'An error occurred while removing the payment method.',
        12 => 'A payment method with that token was not  found.',
        13 => 'Payment method updated successfully.',
        14 => 'An error occurred while updating the payment method.',
        15 => 'Payment method retrieved successfully.',
        21 => 'Payment method added successfully.',
        27 => 'Transaction search completed successfully',
        28 => 'An error occurred while searching transactions.',
        30 => 'Payment method listing successful.',
        31 => 'Transaction retrieved sucessfully.',
        32 => 'A transaction with that ID could not be found.',
        41 => 'Transaction summary retrieved successfully.',
        42 => 'Error retrieving transaction summary',
        46 => 'A transaction with that InvoiceId could not be found.',
        56 => 'The operation failed to complete successfully.',
        95 => 'Timeout occurred, transaction not processed.',
        105 => 'Batch report retrieved successfully.',
        198 => 'Invalid transaction key to perform this action',
        254 => 'Portfolio retrieved successfully',
        275 => 'Invalid transaction type',
        276 => 'Batch search failed.',
        376 => 'Pre-Payment created successfully',
        377 => 'An error occurred while creating the pre-payment',
        378 => 'Pre-Payment retrieval successful.',
        379 => 'Invalid pre-payment uniqueId',
        380 => 'An error occurred while retrieving pre-payment information',
        382 => 'An error occurred while retrieving pre-payment information',
        383 => 'Pre-Payment updated successfully',
        384 => 'Invalid pre-payment uniqueId',
        385 => 'An error occurred while updating the pre-payment'
      }

      def initialize(options = {})
        requires!(options, :transaction_key)
        super
      end

      def purchase(money, payment, options = {})
        return delegate_to_ach(:purchase, money, payment, options) if use_ach_gateway?(payment)

        post = {}

        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)

        commit(auth_purchase_path(payment, options), post)
      end

      def authorize(money, payment, options = {})
        return delegate_to_ach(:authorize, money, payment, options) if use_ach_gateway?(payment)

        options[:action] = :authorize
        purchase(money, payment, options)
      end

      def capture(money, authorization, options = {})
        commit(path(:capture, authorization), {})
      end

      def refund(money, authorization, options = {})
        return delegate_to_ach(:refund, money, authorization, options) if use_ach_gateway?(authorization)

        transaction_id, invoice_id = authorization.split('|')
        post = { Amount: amount(money), InvoiceId: invoice_id }

        commit(path(:refund, transaction_id), post)
      end

      def void(authorization, options = {})
        return delegate_to_ach(:void, authorization, options) if use_ach_gateway?(authorization)

        commit(path(:void, authorization), {})
      end

      def verify(credit_card, options = {})
        post = {}
        add_payment(post, credit_card)
        add_address(post, credit_card, options)

        commit(path(:verify), post)
      end

      def store(credit_card, options = {})
        post = {}
        add_payment(post, credit_card)
        add_address(post, credit_card, options)

        commit(path(:store), post)
      end

      def unstore(authorization, options = {})
        commit(path(:unstore, authorization), {}, :delete)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Transactionkey: )\S+), '\1[FILTERED]').
          gsub(%r((CardNumber=)\d+), '\1[FILTERED]').
          gsub(%r((CardCode=)\d+), '\1[FILTERED]')
      end

      private

      def address_from_options(options)
        options[:billing_address] || options[:address] || {}
      end

      def address_names(address_name, payment_method)
        names = split_names(address_name)
        return names if names.any?(&:present?)

        [payment_method.try(:first_name), payment_method.try(:last_name)]
      end

      def add_address(post, payment_method, options)
        address = address_from_options(options)
        first_name, last_name = address_names(address[:name], payment_method)

        post.merge!(
          BillingFirstName: first_name,
          BillingLastName: last_name,
          BillingAddress1: address[:address1],
          BillingAddress2: address[:address2],
          BillingCity: address[:city],
          BillingState: address[:state],
          BillingZip: address[:zip]
        )
      end

      def add_invoice(post, money, options)
        post[:InvoiceId] = options[:order_id]
        post[:Amount] = amount(money)
      end

      def add_payment(post, payment)
        return unless payment.is_a?(CreditCard)

        post.merge!(
          CardNumber: payment.number,
          CardCode: payment.verification_value,
          ExpMonth: format(payment.month, :two_digits),
          ExpYear: format(payment.year, :two_digits)
        )
      end

      def parse(body)
        JSON.parse(body).with_indifferent_access
      rescue JSON::ParserError, TypeError => e
        {
          errors: body,
          status: 'Unable to parse JSON response',
          message: e.message
        }.with_indifferent_access
      end

      def path(action, value = '')
        placeholder = value.to_s.split('|').first || ''

        {
          purchase: 'v2-3/paymentcards/run',
          authorize: 'v2-3/paymentcards/authorize',
          capture: "v2-1/transactions/#{placeholder}/capture",
          void: "v2/payments/#{placeholder}/void",
          refund: "v2/payments/#{placeholder}/refund",
          verify: 'v2/paymentcards/validate/detailed',
          store: 'v2/paymentcards/add',
          unstore: "v2/paymentcards/#{placeholder}/delete",
          authorize_with_token: "v2-3/payments/paymentcards/#{placeholder}/authorize",
          purchase_with_token: "v2-3/payments/paymentcards/#{placeholder}/run"
        }[action]
      end

      def auth_purchase_path(payment, options)
        action = options.delete(:action) || :purchase
        pm_token = ''

        if payment.is_a?(String)
          pm_token = payment
          action = "#{action}_with_token".to_sym
        end

        path(action, pm_token)
      end

      def url(path)
        "#{test? ? test_url : live_url}/#{path}"
      end

      def request_headers
        { TransactionKey: @options[:transaction_key] }
      end

      def commit(path, post = {}, method = :post, options = {})
        response = parse(ssl_request(method, url(path), post_data(post), request_headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, post),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:Status] == 'Success'
      end

      def message_from(response)
        response[:Message] || response[:ResponseMessage] || response[:Status]
      end

      def authorization_from(response = {}, post = {})
        response[:PaymentMethodToken].presence || [response[:TransactionId], post[:InvoiceId]].compact.join('|')
      end

      def post_data(params)
        URI.encode_www_form(params.compact)
      end

      def error_code_from(response)
        RESPONSE_CODE_MAPPING[response[:ResponseCode].to_i] unless success_from(response)
      end

      def ach_gateway
        @ach_gateway ||= LoanPaymentProAchGateway.new(@options)
      end

      def use_ach_gateway?(payment_or_auth)
        payment_or_auth.is_a?(Check) || (payment_or_auth.is_a?(String) && payment_or_auth.include?('|ach'))
      end

      def delegate_to_ach(method, *args)
        ach_gateway.public_send(method, *args)
      end
    end
  end
end
