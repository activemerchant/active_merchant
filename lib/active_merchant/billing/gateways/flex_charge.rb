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
        refund: 'orders/%s/refund'
      }

      SUCCESS_MESSAGES = %w(APPROVED CHALLENGE SUBMITTED SUCCESS).freeze

      def initialize(options = {})
        requires!(options, :app_key, :app_secret, :site_id, :mid)
        super
      end

      def purchase(money, credit_card, options = {})
        evaluate(:purchase, money, credit_card, options)
      end

      def refund(money, authorization, options = {})
        commit(:refund, { amountToRefund: (money.to_f / 100).round(2) }, authorization)
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
        post[:isRecurring] = cast_bool(options[:is_recurring])
        post[:expiryDateUtc] = options[:mit_expiry_date_utc]
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

      def add_invoice(post, money, credit_card, options)
        post[:transaction] = {
          id: options[:order_id],
          dynamicDescriptor: options[:description],
          timestamp: Time.now.utc.iso8601,
          timezoneUtcOffset: options[:timezone_utc_offset],
          amount: money,
          currency: (options[:currency] || currency(money)),
          responseCode: options[:response_code],
          responseCodeSource: options[:response_code_source] || '',
          avsResultCode: options[:avs_result_code],
          cvvResultCode: options[:cvv_result_code],
          cavvResultCode: options[:cavv_result_code],
          cardNotPresent: credit_card.verification_value.present?
        }.compact
      end

      def add_payment_method(post, credit_card, address, options)
        post[:paymentMethod] = {
          holderName: credit_card.name,
          cardType: 'CREDIT',
          cardBrand: credit_card.brand&.upcase,
          cardCountry: address[:country],
          expirationMonth: credit_card.month,
          expirationYear: credit_card.year,
          cardBinNumber: credit_card.number[0..5],
          cardLast4Digits: credit_card.number[-4..-1],
          cardNumber: credit_card.number,
          Token: false
        }.compact
      end

      def evaluate(action, money, credit_card, options)
        MultiResponse.run do |r|
          r.process { refresh_access_token } unless access_token_valid?
          r.process { peform_evaluation(action, money, credit_card, options) }
        end
      end

      def peform_evaluation(action, money, credit_card, options)
        post = {}
        address = options[:billing_address] || options[:address]
        add_merchant_data(post, options)
        add_base_data(post, options)
        add_invoice(post, money, credit_card, options)
        add_mit_data(post, options)
        add_payment_method(post, credit_card, address, options)
        add_address(post, credit_card, address)
        add_customer_data(post, options)

        commit(:purchase, post)
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
        @options[:access_token].present? && @options.fetch(:expires, 0) > DateTime.now.strftime('%Q').to_i
      end

      def refresh_access_token
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
          response.merge(access_token: @options[:access_token], expires: @options[:expires]), # TODO: Change the flow to add this only on the last one
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        # TODO: Retry at least once on a 401 case
        response = parse(e.response.body)
        Response.new(false, message_from(response), response, test: test?)
      end

      def success_from(response)
        response[:success] && SUCCESS_MESSAGES.include?(response[:status]) ||
          response.dig(:transaction, :payment_method, :token).present?
      end

      def message_from(response)
        response[:title] || response[:responseMessage] || response[:status]
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
