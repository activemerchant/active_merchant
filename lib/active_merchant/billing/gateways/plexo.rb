module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PlexoGateway < Gateway
      self.test_url = 'https://api.testing.plexo.com.uy/v1/payments'
      self.live_url = 'https://api.plexo.com.uy/v1/payments'

      self.supported_countries = ['UY']
      self.default_currency = 'UYU'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.plexo.com.uy'
      self.display_name = 'Plexo'

      APPENDED_URLS = %w(captures refunds cancellations verify)
      AMOUNT_IN_RESPONSE = %w(authonly purchase /verify)
      APPROVED_STATUS = %w(approved authorized)

      def initialize(options = {})
        requires!(options, :client_id, :api_key)
        @credentials = options
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        build_auth_purchase_request(money, post, payment, options)

        commit('purchase', post, options)
      end

      def authorize(money, payment, options = {})
        post = {}
        build_auth_purchase_request(money, post, payment, options)
        add_capture_type(post, options)

        commit('authonly', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:ReferenceId] = options[:reference_id] || generate_unique_id
        post[:Amount] = amount(money)

        commit("/#{authorization}/captures", post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:ReferenceId] = options[:reference_id] || generate_unique_id
        post[:Type] = options[:refund_type] || 'refund'
        post[:Description] = options[:description]
        post[:Reason] = options[:reason]
        post[:Amount] = amount(money)

        commit("/#{authorization}/refunds", post, options)
      end

      def void(authorization, options = {})
        post = {}
        post[:ReferenceId] = options[:reference_id] || generate_unique_id
        post[:Description] = options[:description]
        post[:Reason] = options[:reason]

        commit("/#{authorization}/cancellations", post, options)
      end

      def verify(credit_card, options = {})
        post = {}
        post[:ReferenceId] = options[:reference_id] || generate_unique_id
        post[:MerchantId] = options[:merchant_id] || @credentials[:merchant_id]
        post[:StatementDescriptor] = options[:statement_descriptor] if options[:statement_descriptor]
        post[:CustomerId] = options[:customer_id] if options[:customer_id]
        money = options[:verify_amount].to_i || 100

        add_payment_method(post, credit_card, options)
        add_metadata(post, options[:metadata])
        add_amount(money, post, options)
        add_browser_details(post, options)

        commit('/verify', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("Number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("Cvc\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("InvoiceNumber\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("MerchantId\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def encoded_credentials
        Base64.encode64("#{@credentials[:client_id]}:#{@credentials[:api_key]}").delete("\n")
      end

      def build_auth_purchase_request(money, post, payment, options)
        post[:ReferenceId] = options[:reference_id] || generate_unique_id
        post[:MerchantId] = options[:merchant_id] || @credentials[:merchant_id]
        post[:Installments] = options[:installments] if options[:installments]
        post[:StatementDescriptor] = options[:statement_descriptor] if options[:statement_descriptor]
        post[:CustomerId] = options[:customer_id] if options[:customer_id]

        add_payment_method(post, payment, options)
        add_items(post, options[:items])
        add_metadata(post, options[:metadata])
        add_amount(money, post, options)
        add_browser_details(post, options)
      end

      def header(parameters = {})
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{encoded_credentials}"
        }
      end

      def add_capture_type(post, options)
        post[:Capture] = {}
        post[:Capture][:Method] = options.dig(:capture_type, :method) || 'manual'
      end

      def add_items(post, items)
        return unless items&.kind_of?(Array)

        post[:Items] = []

        items.each do |option_item|
          item = {}
          item[:ReferenceId] = option_item[:reference_id] || generate_unique_id
          item[:Name] = option_item[:name] if option_item[:name]
          item[:Description] = option_item[:description] if option_item[:description]
          item[:Quantity] = option_item[:quantity] if option_item[:quantity]
          item[:Price] = option_item[:price] if option_item[:price]
          item[:Discount] = option_item[:discount] if option_item[:discount]

          post[:Items].append(item)
        end
      end

      def add_metadata(post, metadata)
        return unless metadata&.kind_of?(Hash)

        metadata.transform_keys! { |key| key.to_s.camelize.to_sym }
        post[:Metadata] = metadata
      end

      def add_amount(money, post, amount_options)
        post[:Amount] = {}

        post[:Amount][:Currency] = amount_options[:currency] || self.default_currency
        post[:Amount][:Total] = amount(money)
        post[:Amount][:Details] = {}
        add_amount_details(post[:Amount][:Details], amount_options[:amount_details]) if amount_options[:amount_details]
      end

      def add_amount_details(amount_details, options)
        return unless options

        amount_details[:TaxedAmount] = options[:taxed_amount] if options[:taxed_amount]
        amount_details[:TipAmount] = options[:tip_amount] if options[:tip_amount]
        amount_details[:DiscountAmount] = options[:discount_amount] if options[:discount_amount]
        amount_details[:TaxableAmount] = options[:taxable_amount] if options[:taxable_amount]
        add_tax(amount_details, options[:tax])
      end

      def add_tax(post, tax)
        return unless tax

        post[:Tax] = {}
        post[:Tax][:Type] = tax[:type] if tax[:type]
        post[:Tax][:Amount] = tax[:amount] if tax[:amount]
        post[:Tax][:Rate] = tax[:rate] if tax[:rate]
      end

      def add_browser_details(post, browser_details)
        return unless browser_details

        post[:BrowserDetails] = {}
        post[:BrowserDetails][:DeviceFingerprint] = browser_details[:finger_print] if browser_details[:finger_print]
        post[:BrowserDetails][:IpAddress] = browser_details[:ip] if browser_details[:ip]
      end

      def add_payment_method(post, payment, options)
        post[:paymentMethod] = {}

        if payment&.is_a?(CreditCard)
          post[:paymentMethod][:type] = 'card'
          post[:paymentMethod][:Card] = {}
          post[:paymentMethod][:Card][:Number] = payment.number
          post[:paymentMethod][:Card][:ExpMonth] = format(payment.month, :two_digits) if payment.month
          post[:paymentMethod][:Card][:ExpYear] = format(payment.year, :two_digits) if payment.year
          post[:paymentMethod][:Card][:Cvc] = payment.verification_value if payment.verification_value

          add_card_holder(post[:paymentMethod][:Card], payment, options)
        end
      end

      def add_card_holder(card, payment, options)
        requires!(options, :email)

        cardholder = {}
        cardholder[:FirstName] = payment.first_name if payment.first_name
        cardholder[:LastName] = payment.last_name if payment.last_name
        cardholder[:Email] = options[:email]
        cardholder[:Birthdate] = options[:cardholder_birthdate] if options[:cardholder_birthdate]
        cardholder[:Identification] = {}
        cardholder[:Identification][:Type] = options[:identification_type] if options[:identification_type]
        cardholder[:Identification][:Value] = options[:identification_value] if options[:identification_value]
        add_billing_address(cardholder, options)

        card[:Cardholder] = cardholder
      end

      def add_billing_address(cardholder, options)
        return unless address = options[:billing_address]

        cardholder[:BillingAddress] = {}
        cardholder[:BillingAddress][:City] = address[:city]
        cardholder[:BillingAddress][:Country] = address[:country]
        cardholder[:BillingAddress][:Line1] = address[:address1]
        cardholder[:BillingAddress][:Line2] = address[:address2]
        cardholder[:BillingAddress][:PostalCode] = address[:zip]
        cardholder[:BillingAddress][:State] = address[:state]
      end

      def parse(body)
        return {} if body == ''

        JSON.parse(body)
      end

      def build_url(action, base)
        url = base
        url += action if APPENDED_URLS.any? { |key| action.include?(key) }
        url
      end

      def get_authorization_from_url(url)
        url.split('/')[1]
      end

      def reorder_amount_fields(response)
        return response unless response['amount']

        amount_obj = response['amount']
        response['amount'] = amount_obj['total'].to_i if amount_obj['total']
        response['currency'] = amount_obj['currency'] if amount_obj['currency']
        response['amount_details'] = amount_obj['details'] if amount_obj['details']
        response
      end

      def commit(action, parameters, options = {})
        base_url = (test? ? test_url : live_url)
        url = build_url(action, base_url)
        response = parse(ssl_post(url, parameters.to_json, header(options)))
        response = reorder_amount_fields(response) if AMOUNT_IN_RESPONSE.include?(action)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, action),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 401
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(response)
        APPROVED_STATUS.include?(response['status'])
      end

      def message_from(response)
        response = response['transactions']&.first if response['transactions']&.is_a?(Array)
        response['resultMessage'] || response['message']
      end

      def authorization_from(response, action = nil)
        if action.include?('captures')
          get_authorization_from_url(action)
        else
          response['id']
        end
      end

      def error_code_from(response)
        return if success_from(response)

        response = response['transactions']&.first if response['transactions']&.is_a?(Array)
        response['resultCode'] || response['status']
      end
    end
  end
end
