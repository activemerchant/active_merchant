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
        fetch_session_token unless session_token_valid?
      end

      def authorize(money, payment, options = {})
        post = { transactionType: 'Auth' }

        build_post_data(post, :authorize)
        add_amount(post, money, options)
        add_payment_method(post, payment)
        add_address(post, payment, options)
        add_customer_ip(post, options)

        commit(:purchase, post)
      end

      def purchase(money, payment, options = {}); end

      def capture(money, authorization, options = {})
        post = { relatedTransactionId: authorization }

        build_post_data(post, :capture)
        add_amount(post, money, options)

        commit(:capture, post)
      end

      def refund(money, authorization, options = {}); end

      def void(authorization, options = {}); end

      def credit(money, payment, options = {}); end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("cardNumber\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r(("cardCvv\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantId\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantSiteId\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("merchantKey\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_customer_ip(post, options)
        return unless options[:ip]

        post[:deviceDetails] = { ipAddress: options[:ip] }
      end

      def add_amount(post, money, options)
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

      def add_payment_method(post, payment)
        if payment.is_a?(CreditCard)
          post[:paymentOption] = { card: credit_card_hash(payment) }
        else
          post[:paymentOption] = { card: { cardToken: payment } }
        end
      end

      def add_customer_names(full_name, payment_method)
        split_names(full_name).tap do |names|
          names[0] = payment_method&.first_name unless names[0].present? || payment_method.is_a?(String)
          names[1] = payment_method&.last_name unless names[1].present? || payment_method.is_a?(String)
        end
      end

      def add_address(post, payment, options)
        return unless address = options[:billing_address] || options[:address]

        first_name, last_name = add_customer_names(address[:name], payment)

        post[:billingAddress] = {
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

      def build_post_data(post, action)
        post[:merchantId] = @options[:merchant_id]
        post[:merchantSiteId] = @options[:merchant_site_id]
        post[:timeStamp] = current_timestamp.to_i
        post[:clientRequestId] = SecureRandom.uuid
        post[:clientUniqueId] = SecureRandom.hex(16)
      end

      def calculate_checksum(post, action)
        common_keys = %i[merchantId merchantSiteId clientRequestId]
        keys = case action
               when :authenticate
                 [:timeStamp]
               when :capture
                 %i[clientUniqueId amount currency relatedTransactionId timeStamp]
               else
                 %i[amount currency timeStamp]
               end

        to_sha = post.values_at(*common_keys.concat(keys)).push(@options[:secret_key]).join
        Digest::SHA256.hexdigest(to_sha)
      end

      def send_session_request(post)
        post[:checksum] = calculate_checksum(post, 'authenticate')
        response = parse(ssl_post(url(:authenticate), post.to_json, headers)).with_indifferent_access
        expiration_time = post[:timeStamp]
        @options[:session_token] = response.dig('sessionToken')
        @options[:token_expires] = expiration_time

        Response.new(
          response[:sessionToken].present?,
          message_from(response),
          response,
          test: test?,
          error_code: response[:errCode]
        )
      end

      def fetch_session_token(post = {})
        build_post_data(post, :authenticate)
        send_session_request(post)
      end

      def session_token_valid?
        return false unless @options[:session_token] && @options[:token_expires]

        (Time.now.utc.to_i - @options[:token_expires].to_i) < 900 # 15 minutes
      end

      def commit(action, post, authorization = nil, method = :post)
        post[:sessionToken] = @options[:session_token] unless action == :capture
        post[:checksum] = calculate_checksum(post, action)

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
        @options[:session_token] = '' if e.response.code == '401'

        Response.new(false, message_from(response), response, test: test?)
      end

      def url(action, id = nil)
        "#{test? ? test_url : live_url}#{ENDPOINTS_MAPPING[action] % id}"
      end

      def error_code_from(action, response)
        (response[:statusName] || response[:status]) unless success_from(response)
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
        response[:status]
      end
    end
  end
end
