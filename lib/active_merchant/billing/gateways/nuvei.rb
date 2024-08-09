module ActiveMerchant
  module Billing
    class NuveiGateway < Gateway
      self.test_url = 'https://ppp-test.nuvei.com/ppp/api/v1'
      self.live_url = 'https://secure.safecharge.com/ppp/api/v1'

      self.supported_countries = %w[US CA IN NZ GB AU US]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover union_pay]
      self.currencies_without_fractions = %w[CLP KRW JPY ISK MMK PYG UGX VND XAF XOF]
      self.homepage_url = 'https://www.nuvei.com/'
      self.display_name = 'Nuvei'

      ENDPOINTS_MAPPING = {
        authenticate: '/getSessionToken',
        purchase: '/payment', # /authorize with transactionType: "Auth"
        capture: '/settleTransaction',
        refund: '/refundTransaction',
        void: '/voidTransaction',
        general_credit: '/payout'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_site_id, :secret_key)
        super
      end

      def initialize_post(transaction_type = 'Sale')
        post = {}
        post[:transactionType] = transaction_type if transaction_type
        post
      end

      def authorize(money, payment, options = {})
        post = initialize_post('Auth')
        build_authorize_and_purchase_params(money, payment, options, post)
      end

      def purchase(money, payment, options = {})
        build_authorize_and_purchase_params(money, payment, options)
      end

      def build_authorize_and_purchase_params(money, payment, options = {}, post = {})
        post ||= {}
        build_post_data(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_ip(post, options)

        commit(:purchase, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:relatedTransactionId] = authorization
        build_post_data(post)
        add_invoice(post, money, options)

        commit(:capture, post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:relatedTransactionId] = authorization
        build_post_data(post)
        add_invoice(post, money, options)

        commit(:refund, post)
      end

      def void(authorization, options = {})
        post = {}
        post[:relatedTransactionId] = authorization
        build_post_data(post)

        commit(:void, post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def credit(money, payment, options = {})
        post = {}
        post[:userTokenId] = options[:user_token_id] if options[:user_token_id]
        build_post_data(post)
        add_invoice(post, money, options)
        add_payment(post, payment, :cardData)
        add_address(post, payment, options)
        add_customer_ip(post, options)
        commit(:general_credit, post)
      end

      def store(amount, payment, options = {})
        post = {
          paymentOption: {
            card: credit_card_hash(payment).merge!(savePM: save_payment_method?(options))
          }
        }

        build_post_data(post)
        add_invoice(post, amount, options)
        add_address(post, payment, options)
        add_customer_ip(post, options)

        commit(:purchase, post)
      end

      def save_payment_method?(options)
        options.include?(:savePM) and options[:savePM] == true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("cardNumber\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r(("cardCvv\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cardHolderName\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantId\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantSiteId\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantKey\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_customer_ip(post, options)
        return unless options[:ip_address]

        post[:deviceDetails] = {
          ipAddress: options[:ip_address]
        }
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def credit_card_hash(payment)
        {
          cardNumber: payment.number,
          cardHolderName: payment.name,
          expirationMonth: format(payment.month, :two_digits),
          expirationYear: format(payment.year, :four_digits),
          CVV: payment.verification_value
        }
      end

      def add_payment(post, payment, key = :paymentOption)
        payment_data = payment.is_a?(CreditCard) ? credit_card_hash(payment) : { cardToken: payment }

        if key == :cardData
          post[key] = payment_data
        else
          post[key] = { card: payment_data }
        end
      end

      def add_customer_names(full_name, payment_method)
        split_names(full_name).tap do |names|
          names[0] = payment_method&.first_name unless names[0].present? || payment_method.is_a?(String)
          names[1] = payment_method&.last_name unless names[1].present? || payment_method.is_a?(String)
        end
      end

      def add_address(post, payment, options, address_type = :billingAddress)
        return unless address = options[:billing_address] || options[:address]

        first_name, last_name = add_customer_names(address[:name], payment)

        post[address_type] = {
          email: options[:email],
          country: address[:country],
          phone: options[:phone] || address[:phone],
          firstName: first_name,
          lastName: last_name
        }.compact
      end

      def current_timestamp
        Time.now.utc.strftime('%Y%m%d%H%M%S')
      end

      def build_post_data(post)
        post[:merchantId] = @options[:merchant_id]
        post[:merchantSiteId] = @options[:merchant_site_id]
        post[:timeStamp] = current_timestamp.to_i
        post[:clientRequestId] = SecureRandom.uuid
        post[:clientUniqueId] = SecureRandom.hex(16)
      end

      def calculate_checksum(post, action)
        case action
        when :authenticate
          Digest::SHA256.hexdigest("#{post[:merchantId]}#{post[:merchantSiteId]}#{post[:clientRequestId]}#{post[:timeStamp]}#{@options[:secret_key]}")
        when :capture, :refund, :void
          Digest::SHA256.hexdigest("#{post[:merchantId]}#{post[:merchantSiteId]}#{post[:clientRequestId]}#{post[:clientUniqueId]}#{post[:amount]}#{post[:currency]}#{post[:relatedTransactionId]}#{post[:timeStamp]}#{@options[:secret_key]}")
        else
          Digest::SHA256.hexdigest("#{post[:merchantId]}#{post[:merchantSiteId]}#{post[:clientRequestId]}#{post[:amount]}#{post[:currency]}#{post[:timeStamp]}#{@options[:secret_key]}")
        end
      end

      def send_request(post)
        post[:checksum] = calculate_checksum(post, 'authenticate')

        response = parse(ssl_post(url(:authenticate), post.to_json, headers)).with_indifferent_access

        expiration_time = post[:timeStamp]
        @options[:session_token] = response.dig('sessionToken')
        @options[:token_expires] = expiration_time
        @options[:valid_credentials] = true

        Response.new(
          response[:sessionToken].present?,
          message_from(response),
          response,
          test: test?,
          error_code: response[:gwErrorCode]
        )
      end

      def fetch_session_token(post = {})
        build_post_data(post)
        send_request(post)
      end

      def session_token_valid?
        return false unless @options[:session_token] && @options[:token_expires]

        token_time = @options[:token_expires].to_i
        current_time = Time.now.utc.to_i
        (current_time - token_time) < 15 * 60
      end

      def commit(action, post, authorization = nil, method = :post)
        MultiResponse.run do |r|
          r.process { fetch_session_token } unless session_token_valid?
          r.process do
            api_request(action, post, authorization, method).tap do |response|
              response.params.merge!(@options.slice(:session_token, :token_expires)) if @options[:valid_credentials]
            end
          end
        end
      end

      def url(action, id = nil)
        "#{test? ? test_url : live_url}#{ENDPOINTS_MAPPING[action] % id}"
      end

      def error_code_from(action, response)
        response[:errCode] == 0 ? response[:gwErrorCode] : response[:errCode]
      end

      def api_request(action, post, authorization, method = :post)
        @options[:checksum] = calculate_checksum(post, action)
        post[:sessionToken] = @options[:session_token] unless %i(capture refund).include?(action)
        post[:checksum] = @options[:checksum]

        response = parse(ssl_request(method, url(action, authorization), post.to_json, headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response, post),
          test: test?,
          error_code: error_code_from(action, response)
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        # if current access_token is invalid then clean it
        if e.response.code == '401'
          @options[:session_token] = ''
          @options[:new_credentials] = true
        end
        Response.new(false, message_from(response), response, test: test?)
      end

      def headers
        { 'Content-Type' => 'application/json' }.tap do |headers|
          headers['Authorization'] = "Bearer #{@options[:session_token]}" if @options[:session_token]
        end
      end

      def parse(body)
        body = '{}' if body.blank?

        JSON.parse(body).with_indifferent_access
      rescue JSON::ParserError
        {
          errors: body,
          status: 'Unable to parse JSON response'
        }.with_indifferent_access
      end

      def success_from(response)
        response[:status] == 'SUCCESS' && response[:transactionStatus] == 'APPROVED'
      end

      def authorization_from(action, response, post)
        response.dig(:transactionId)
      end

      def message_from(response)
        reason = response[:reason]&.present? ? response[:reason] : nil
        response[:gwErrorReason] || reason || response[:transactionStatus]
      end
    end
  end
end
