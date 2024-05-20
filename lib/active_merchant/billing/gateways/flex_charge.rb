module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FlexChargeGateway < Gateway
      self.test_url = 'https://api-sandbox.flex-charge.com/v1/'
      self.live_url = 'https://api.flex-charge.com/v1/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]
      self.money_format = :cents
      self.homepage_url = 'https://www.flex-charge.com/'
      self.display_name = 'FlexCharge'

      ENDPOINTS_MAPPING = {
        authenticate: 'oauth2/token',
        purchase: 'evaluate',
        sync: 'outcome',
        refund: 'orders/%s/refund',
        store: 'tokenize',
        inquire: 'outcome'
      }

      SUCCESS_MESSAGES = %w(APPROVED CHALLENGE SUBMITTED SUCCESS PROCESSING).freeze

      def initialize(options = {})
        requires!(options, :app_key, :app_secret, :site_id, :mid)
        super
      end

      def purchase(money, credit_card, options = {})
        post = {}
        address = options[:billing_address] || options[:address]
        add_merchant_data(post, options)
        add_base_data(post, options)
        add_invoice(post, money, credit_card, options)
        add_mit_data(post, options)
        add_payment_method(post, credit_card, address, options)
        add_address(post, credit_card, address)
        add_customer_data(post, options)
        add_three_ds(post, options)

        commit(:purchase, post)
      end

      def refund(money, authorization, options = {})
        commit(:refund, { amountToRefund: (money.to_f / 100).round(2) }, authorization)
      end

      def store(credit_card, options = {})
        address = options[:billing_address] || options[:address] || {}
        first_name, last_name = address_names(address[:name], credit_card)

        post = {
          payment_method: {
            credit_card: {
              first_name: first_name,
              last_name: last_name,
              month: credit_card.month,
              year: credit_card.year,
              number: credit_card.number,
              verification_value: credit_card.verification_value
            }.compact
          }
        }
        commit(:store, post)
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

      def inquire(authorization, options = {})
        commit(:inquire, { orderSessionKey: authorization }, authorization)
      end

      private

      def add_three_ds(post, options)
        return unless three_d_secure = options[:three_d_secure]

        post[:threeDSecure] = {
          threeDsVersion: three_d_secure[:version],
          EcommerceIndicator: three_d_secure[:eci],
          authenticationValue: three_d_secure[:cavv],
          directoryServerTransactionId:  three_d_secure[:ds_transaction_id],
          xid: three_d_secure[:xid],
          authenticationValueAlgorithm: three_d_secure[:cavv_algorithm],
          directoryResponseStatus: three_d_secure[:directory_response_status],
          authenticationResponseStatus: three_d_secure[:authentication_response_status],
          enrolled: three_d_secure[:enrolled]
        }
      end

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
        return if options[:is_mit].nil?

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
          cardNotPresent: credit_card.is_a?(String) ? false : credit_card.verification_value.blank?
        }.compact
      end

      def add_payment_method(post, credit_card, address, options)
        payment_method = case credit_card
                         when String
                           { Token: true, cardNumber: credit_card }
                         else
                           {
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
                           }
                         end
        post[:paymentMethod] = payment_method.compact
      end

      def address_names(address_name, payment_method)
        split_names(address_name).tap do |names|
          names[0] = payment_method&.first_name unless names[0].present?
          names[1] = payment_method&.last_name unless names[1].present?
        end
      end

      def phone_from(options)
        options[:phone] || options.dig(:billing_address, :phone_number)
      end

      def access_token_valid?
        @options[:access_token].present? && @options.fetch(:token_expires, 0) > DateTime.now.strftime('%Q').to_i
      end

      def fetch_access_token
        params = { AppKey: @options[:app_key], AppSecret: @options[:app_secret] }
        response = parse(ssl_post(url(:authenticate), params.to_json, headers))

        @options[:access_token] = response[:accessToken]
        @options[:token_expires] = response[:expires]
        @options[:new_credentials] = true

        Response.new(
          response[:accessToken].present?,
          message_from(response),
          response,
          test: test?,
          error_code: response[:statusCode]
        )
      rescue ResponseError => e
        raise OAuthResponseError.new(e)
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
        {
          errors: body,
          status: 'Unable to parse JSON response'
        }.with_indifferent_access
      end

      def commit(action, post, authorization = nil)
        MultiResponse.run do |r|
          r.process { fetch_access_token } unless access_token_valid?
          r.process do
            api_request(action, post, authorization).tap do |response|
              response.params.merge!(@options.slice(:access_token, :token_expires)) if @options[:new_credentials]
            end
          end
        end
      end

      def api_request(action, post, authorization = nil)
        response = parse ssl_post(url(action, authorization), post.to_json, headers)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        # if current access_token is invalid then clean it
        if e.response.code == '401'
          @options[:access_token] = ''
          @options[:new_credentials] = true
        end
        Response.new(false, message_from(response), response, test: test?)
      end

      def success_from(response)
        response[:success] && SUCCESS_MESSAGES.include?(response[:status]) ||
          response.dig(:transaction, :payment_method, :token).present?
      end

      def message_from(response)
        response[:title] || response[:responseMessage] || response[:status]
      end

      def authorization_from(action, response)
        action == :store ? response.dig(:transaction, :payment_method, :token) : response[:orderSessionKey]
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
