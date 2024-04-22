module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FlexChargeGateway < Gateway
      self.test_url = 'https://api-sandbox.flex-charge.com/v1/'
      self.live_url = 'https://api.flex-charge.com/v1/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.flex-charge.com/'
      self.display_name = 'FlexCharge'

      STANDARD_ERROR_CODE_MAPPING = {}

      ENDPOINTS_MAPPING = {
        authenticate: 'oauth2/token',
        purchase: 'evaluate',
        sync: 'outcome',
        refund: 'orders/%s/refund',
        tokenize: 'tokenize'
      }

      TRANSACTION_TYPES_MAPPING = {
        authorize: 'Auth',
        capture: 'Capture',
        void: 'Void'
      }

      SUCCESS_MESSAGES = %w(APPROVED CHALLENGE SUBMITTED).freeze

      def initialize(options = {})
        requires!(options, :app_key, :app_secret, :site_id, :mid)
        super
      end

      def purchase(money, credit_card, options = {})
        evaluate(:purchase, money, credit_card, options)
      end

      def authorize(money, credit_card, options = {})
        evaluate(:authorize, money, credit_card, options)
      end

      def capture(money, authorization, options = {})
        evaluate(:capture, money, credit_card, options)
      end

      def refund(money, authorization, options = {})
        commit(:refund, { amountToRefund: amount(money) }, authorization)
      end

      def void(authorization, options = {})
        evaluate(:void, money, credit_card, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )[a-zA-Z0-9._-]+)i, '\1[FILTERED]').
          gsub(%r(("AppKey\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("AppSecret\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("accessToken\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("mid\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("siteId\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("environment\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cardNumber\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("verification_value\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_merchant_data(post, options)
        post[:siteId] = @options[:site_id]
        post[:mid] = @options[:mid]
      end

      def add_base_data(post, options)
        post[:isDeclined] = cast_bool(options[:is_declined])
        post[:orderId] = options[:order_id]
        post[:idempotencyKey] = options[:idempotency_key] || options[:order_id]
      end

      def add_mit_data(post, options)
        return unless options[:is_mit].present?

        post[:isMIT] = cast_bool(options[:is_mit])
      end

      def add_customer_data(post, options)
        post[:payer] = { email: options[:email] || 'NA', phone: phone_from(options) }.compact
      end

      def add_address(post, payment, address)
        first_name, last_name = address_names(address[:name], payment)

        post[:billingInformation] = {
          firstName: first_name,
          lastName: last_name,
          country: address[:country],
          phone: address[:phone],
          countryCode: address[:country],
          addressLine1: address[:address1],
          state: address[:state],
          city: address[:city],
          zipCode: address[:zip]
        }.compact
      end

      def add_invoice(post, money, options)
        post[:transaction] = {
          id: options[:order_id],
          timestamp: Time.now.utc.iso8601, # TODO: Check if this is the correct format
          timezoneUtcOffset: options[:timezone_utc_offset],
          amount: money,
          currency: (options[:currency] || currency(money)),
          responseCode: options[:response_code],
          responseCodeSource: options[:response_code_source] || '',
          avsResultCode: options[:avs_result_code],
          cvvResultCode: options[:cvv_result_code],
          cavvResultCode: options[:cavv_result_code],
          cardNotPresent: options[:card_not_present]
        }.compact
      end

      def add_transaction_type(post, action)
        post[:transaction][:transactionType] = TRANSACTION_TYPES_MAPPING[action]
      end

      def add_payment_method(post, credit_card, address, options)
        payment_token = options[:payment_token] || {}

        post[:paymentMethod] = {
          holderName: credit_card.name,
          cardType: payment_token[:card_type]&.upcase || 'CREDIT',
          cardBrand: credit_card.brand&.upcase,
          cardCountry: payment_token[:country] || address[:country],
          expirationMonth: credit_card.month,
          expirationYear: credit_card.year,
          cardBinNumber: payment_token[:first_six_digits] || credit_card.number[0..5],
          cardLast4Digits: payment_token[:last_four_digits] || credit_card.number[-4..-1],
          cardNumber: payment_token[:token] || credit_card.number,
          Token: false
        }.compact
      end

      def add_credit_card(post, credit_card, options)
        first_name, last_name = split_names(credit_card.name)
        post[:payment_method] = {
          sense_key: options[:order_id],
          credit_card: {
            first_name: first_name,
            last_name: last_name,
            number: credit_card.number,
            verification_value: credit_card.verification_value,
            month: credit_card.month,
            year: credit_card.year
          }
        }.compact
      end

      def add_credentials_for_tokenization(post)
        post[:mid] = @options[:mid]
        post[:environment] = @options[:tokenization_key]
      end

      def evaluate(action, money, credit_card, options)
        MultiResponse.run do |r|
          r.process { get_access_token } unless access_token_valid?

          if options[:tokenize]
            r.process { tokenize(credit_card, options) }
            options[:payment_token] = r.params.dig(:transaction, :payment_method)
          end

          r.process { peform_evaluation(action, money, credit_card, options) }
        end
      end

      def peform_evaluation(action, money, credit_card, options)
        post = {}
        address = options[:billing_address] || options[:address]
        add_merchant_data(post, options)
        add_base_data(post, options)
        add_invoice(post, money, options)
        add_mit_data(post, options)
        add_payment_method(post, credit_card, address, options)
        add_address(post, credit_card, address)
        add_customer_data(post, options)
        add_transaction_type(post, action)

        commit(:purchase, post)
      end

      def tokenize(credit_card, options)
        post = {}
        add_credentials_for_tokenization(post)
        add_credit_card(post, credit_card, options)

        commit(:tokenize, post, headers)
      end

      def address_names(address_name, payment_method)
        names = split_names(address_name)

        [
          names.first || payment_method&.first_name,
          names.last || payment_method&.last_name
        ]
      end

      def phone_from(options)
        options[:phone] || options.dig(:billing_address, :phone_number)
      end

      def access_token_valid?
        @options[:access_token].present? && @options.fetch(:expires, 0) <= DateTime.now.strftime('%Q').to_i
      end

      def get_access_token
        params = { AppKey: @options[:app_key], AppSecret: @options[:app_secret] }
        response = parse(ssl_post(url(:authenticate), params.to_json, headers))

        @options[:access_token] = response[:accessToken]
        @options[:expires] = response[:expires]

        Response.new(
          response[:accessToken].present?,
          message_from(response),
          response,
          test: test?,
          error_code: response[:statusCode]
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        Response.new(false, message_from(response), response, test: test?)
      end

      def url(action, id = nil)
        "#{test? ? test_url : live_url}#{ENDPOINTS_MAPPING[action] % id}"
      end

      def headers
        { 'Content-Type' => 'application/json' }.tap do |headers|
          headers['Authorization'] = "Bearer #{@options[:access_token]}" if @options[:access_token]
        end
      end

      def parse(body)
        JSON.parse(body).with_indifferent_access
      rescue JSON::ParserError
        { errors: body,
          status: 'Unable to parse JSON response' }.with_indifferent_access
      end

      def commit(action, post, authorization = nil)
        response = parse ssl_post(url(action, authorization), post.to_json, headers)

        Response.new(
          success_from(response),
          message_from(response),
          response.merge(access_token: @options[:access_token], expires: @options[:expires]),
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        Response.new(false, message_from(response), response, test: test?)
      end

      def success_from(response)
        response[:success] && SUCCESS_MESSAGES.include?(response[:status]) ||
          response.dig(:transaction, :payment_method, :token).present?
      end

      def message_from(response)
        response[:errors].present? ? response[:errors].to_s : response[:status]
      end

      def authorization_from(response)
        response[:orderSessionKey]
      end

      def error_code_from(response)
        response[:status] unless success_from(response)
      end

      def cast_bool(value)
        ![false, 0, '', '0', 'f', 'F', 'false', 'FALSE'].include?(value)
      end
    end
  end
end
