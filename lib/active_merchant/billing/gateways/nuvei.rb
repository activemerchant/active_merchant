module ActiveMerchant
  module Billing
    class NuveiGateway < Gateway
      self.test_url = 'https://ppp-test.nuvei.com/ppp/api/v1'
      self.live_url = 'https://secure.safecharge.com/ppp/api/v1'

      self.supported_countries = %w[US CA IN NZ GB AU US]
      self.default_currency = 'USD'
      self.money_format = :dollars
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
        general_credit: '/payout',
        init_payment: '/initPayment'
      }

      NETWORK_TOKENIZATION_CARD_MAPPING = {
        'apple_pay' => 'ApplePay',
        'google_pay' => 'GooglePay'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_site_id, :secret_key)
        super
        fetch_session_token unless session_token_valid?
      end

      def authorize(money, payment, options = {}, transaction_type = 'Auth')
        post = { transactionType: transaction_type }
        post[:savePM] = options[:save_payment_method] ? options[:save_payment_method].to_s : 'false'

        build_post_data(post, options)
        add_amount(post, money, options)
        add_payment_method(post, payment, :paymentOption, options)
        add_3ds_global(post, options)
        add_address(post, payment, options)
        add_customer_ip(post, options)
        add_stored_credentials(post, payment, options)
        add_account_funding_transaction(post, payment, options)
        add_cardholder_name_verification(post, payment, transaction_type, options)
        post[:userTokenId] = options[:user_token_id] if options[:user_token_id]
        post[:isPartialApproval] = options[:is_partial_approval] ? 1 : 0
        post[:authenticationOnlyType] = options[:authentication_only_type] if options[:authentication_only_type]

        if options[:execute_threed]
          execute_3ds_flow(post, money, payment, transaction_type, options)
        else
          commit(:purchase, post)
        end
      end

      def purchase(money, payment, options = {})
        fetch_session_token if payment.is_a?(String)
        authorize(money, payment, options, 'Sale')
      end

      def capture(money, authorization, options = {})
        post = { relatedTransactionId: authorization }

        build_post_data(post)
        add_amount(post, money, options)

        commit(:capture, post)
      end

      def refund(money, authorization, options = {})
        post = { relatedTransactionId: authorization }

        build_post_data(post)
        add_amount(post, money, options)

        commit(:refund, post)
      end

      def void(authorization, options = {})
        post = { relatedTransactionId: authorization }
        build_post_data(post)

        commit(:void, post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(credit_card, options = {})
        options[:save_payment_method] = true
        authorize(0, credit_card, options)
      end

      def credit(money, payment, options = {})
        post = { userTokenId: options[:user_token_id] }
        payment_key = payment.is_a?(NetworkTokenizationCreditCard) ? :userPaymentOption : :cardData
        build_post_data(post)
        add_amount(post, money, options)
        options[:is_payout] ? send_payout_transaction(payment_key, post, payment, options) : send_unreferenced_refund_transaction(post, payment, options)
      end

      def send_payout_transaction(payment_key, post, payment, options = {})
        add_payment_method(post, payment, payment_key, options)
        add_customer_ip(post, options)
        url_details(post, options)
        commit(:general_credit, post.compact)
      end

      def send_unreferenced_refund_transaction(post, payment, options = {})
        post[:paymentOption] = { userPaymentOptionId: options[:user_payment_option_id] } if options[:user_payment_option_id]
        unless options[:user_payment_option_id]
          add_payment_method(post, payment, :paymentOption, options)
          post[:paymentOption][:card].slice!(:cardNumber, :cardHolderName, :expirationMonth, :expirationYear, :CVV)
        end
        commit(:refund, post.compact)
      end

      def add_stored_credentials(post, payment, options = {})
        return unless options[:stored_credential]

        post[:savePM] = options[:save_payment_method] || true
        set_initiator_type(post, payment, options)
        set_reason_type(post, options)
      end

      def set_initiator_type(post, payment, options)
        stored_credential = options[:stored_credential]
        return unless stored_credential

        is_initial_transaction = stored_credential[:initial_transaction]
        stored_credentials_mode = is_initial_transaction ? '0' : '1'

        if payment.is_a?(CreditCard)
          post[:paymentOption] ||= {}
          post[:paymentOption][:card] ||= {}
          post[:paymentOption][:card][:storedCredentials] ||= {}
          post[:paymentOption][:card][:storedCredentials][:storedCredentialsMode] = stored_credentials_mode
        end
        post[:isRebilling] = options[:is_rebilling] ? '1' : '0' if mit?(options[:stored_credential])
      end

      def mit?(stored_credential)
        stored_credential[:reason_type] != 'unscheduled' && stored_credential[:initial_transaction] == false
      end

      def add_account_funding_transaction(post, payment, options = {})
        return unless options[:is_aft]

        recipient_details = {
          firstName: options[:aft_recipient_first_name],
          lastName: options[:aft_recipient_last_name]
        }.compact

        address_details = {
          firstName: payment.first_name,
          lastName: payment.last_name,
          country: options.dig(:billing_address, :country),
          address: options.dig(:billing_address, :address1),
          city: options.dig(:billing_address, :city),
          state: options.dig(:billing_address, :state)
        }.compact

        post[:billingAddress].merge!(address_details)
        post[:recipientDetails] = recipient_details unless recipient_details.empty?
      end

      def set_reason_type(post, options)
        reason_type = options[:stored_credential][:reason_type]

        case reason_type
        when 'recurring'
          reason_type = 'RECURRING'
        when 'installment'
          reason_type = 'INSTALLMENTS'
        when 'unscheduled'
          reason_type = 'ADDCARD'
        end

        unless reason_type == 'ADDCARD'
          fetch_session_token
          post[:relatedTransactionId] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
        end

        post[:authenticationOnlyType] = reason_type
      end

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
          gsub(%r(("merchantKey\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("accountNumber\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cryptogram\\?":\\?")[^"\\]*)i, '\1[FILTERED]')
      end

      private

      def network_transaction_id_from(response)
        response.dig('transactionId')
      end

      def add_customer_ip(post, options)
        return unless options[:ip]

        post[:deviceDetails] = { ipAddress: options[:ip] }
      end

      def url_details(post, options)
        return unless options[:notification_url]

        post[:urlDetails] = { notificationUrl: options[:notification_url] }
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
          CVV: payment.verification_value,
          last4Digits: get_last_four_digits(payment.number),
          selectedBrand: payment.brand
        }
      end

      def get_last_four_digits(number)
        number[-4..-1]
      end

      def add_bank_account(post, payment, options)
        post[:paymentOption] = {
          alternativePaymentMethod: {
            paymentMethod: 'apmgw_ACH',
            AccountNumber: payment.account_number,
            RoutingNumber: payment.routing_number,
            SECCode: options[:account_type] || 'WEB'
          }
        }
      end

      def add_payment_method(post, payment, key, options = {})
        return post[key] = { userPaymentOptionId: options[:user_payment_option_id] } if key == :userPaymentOption

        payment_data = extract_payment_data(payment)

        case payment
        when NetworkTokenizationCreditCard
          add_network_tokenization_data(post, payment, payment_data)
        when CreditCard
          post[key] = key == :paymentOption ? { card: payment_data } : payment_data
        when Check
          add_bank_account(post, payment, options)
          url_details(post, options)
        else
          post[key] = { userPaymentOptionId: payment_data }
        end
      end

      def extract_payment_data(payment)
        if payment.is_a?(CreditCard) || payment.is_a?(NetworkTokenizationCreditCard)
          credit_card_hash(payment)
        else
          payment
        end
      end

      def add_network_tokenization_data(post, payment, payment_data)
        payment_data[:brand] = payment.brand.upcase
        external_token = {
          externalTokenProvider: NETWORK_TOKENIZATION_CARD_MAPPING[payment.source.to_s],
          cryptogram: payment.payment_cryptogram,
          eciProvider: payment.eci
        }.compact

        payment_data.slice!(:cardNumber, :expirationMonth, :expirationYear, :last4Digits, :brand, :CVV)
        post[:paymentOption] = { card: payment_data.merge(externalToken: external_token) }
      end

      def add_customer_names(full_name, payment_method)
        split_names(full_name).tap do |names|
          names[0] = payment_method&.first_name unless names[0].present? || payment_method.is_a?(String)
          names[1] = payment_method&.last_name unless names[1].present? || payment_method.is_a?(String)
        end
      end

      def add_3ds_global(post, options)
        return unless (three_d_secure_options = options[:three_d_secure])

        card_options = post[:paymentOption][:card] ||= {}
        card_options[:threeD] = build_three_d_secure_options(three_d_secure_options, options)
      end

      def build_three_d_secure_options(three_d_secure_options, options)
        three_d_secure_data = {
          externalMpi: {
            eci: three_d_secure_options[:eci],
            cavv: three_d_secure_options[:cavv],
            dsTransID: three_d_secure_options[:ds_transaction_id],
            challengePreference: options[:challenge_preference]
          }
        }.compact

        three_d_secure_data[:externalMpi][:exemptionRequestReason] = options[:exemption_request_reason] if options[:challenge_preference] == 'ExemptionRequest'

        three_d_secure_data
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

      def add_cardholder_name_verification(post, payment, transaction_type, options)
        return unless transaction_type == 'Auth'

        post[:cardHolderNameVerification] = { performNameVerification: 'true' } if options[:perform_name_verification]

        cardholder_data = {
          firstName: payment.first_name,
          lastName: payment.last_name
        }.compact

        post[:billingAddress] ||= {}
        post[:billingAddress].merge!(cardholder_data)
      end

      def execute_3ds_flow(post, money, payment, transaction_type, options = {})
        post_3ds = post.dup

        MultiResponse.run do |r|
          r.process { commit(:init_payment, post) }
          r.process do
            three_d_params = r.params.dig('paymentOption', 'card', 'threeD')
            three_d_supported = three_d_params['v2supported'] == 'true'

            [true, 'true'].include?(options[:force_3d_secure])

            next r.process { Response.new(false, '3D Secure is required but not supported') } if !three_d_supported && [true, 'true'].include?(options[:force_3d_secure])

            if three_d_supported
              add_3ds_data(post_3ds, options.merge(version: three_d_params['version']))
              post_3ds[:relatedTransactionId] = r.authorization
            end

            commit(:purchase, post_3ds)
          end
        end
      end

      def add_3ds_data(post, options = {})
        return unless options[:three_ds_2]

        three_d_secure = options[:three_ds_2]
        # 01 => Challenge requested, 02 => Exemption requested, 03 or not sending parameter => No preference
        challenge_preference = if [true, 'true'].include?(options[:force_3d_secure])
                                 '01'
                               elsif [false, 'false'].include?(options[:force_3d_secure])
                                 '02'
                               end
        browser_info_3ds = three_d_secure[:browser_info]
        payment_options = post[:paymentOption] ||= {}
        card = payment_options[:card] ||= {}
        card[:threeD] = {
          v2AdditionalParams: {
            challengeWindowSize: options[:browser_size],
            challengePreference: challenge_preference
          }.compact,
        browserDetails: {
          acceptHeader: browser_info_3ds[:accept_header],
          ip: options[:ip],
          javaEnabled: browser_info_3ds[:java],
          javaScriptEnabled: browser_info_3ds[:javascript] || false,
          language: browser_info_3ds[:language],
          colorDepth: browser_info_3ds[:depth], # Possible values: 1, 4, 8, 15, 16, 24, 32, 48
          screenHeight: browser_info_3ds[:height],
          screenWidth: browser_info_3ds[:width],
          timeZone: browser_info_3ds[:timezone],
          userAgent: browser_info_3ds[:user_agent]
        }.compact,
        notificationURL: (options[:notification_url] || options[:callback_url]),
        merchantURL: options[:merchant_url], # The URL of the merchant's fully qualified website.
        version: options[:version], # returned from initPayment
        methodCompletionInd: 'U', # to indicate "unavailable".
        platformType: '02' # browser instead of app-based (app-based is only for SDK implementation)
        }.compact
      end

      def current_timestamp
        Time.now.utc.strftime('%Y%m%d%H%M%S')
      end

      def build_post_data(post, options = {})
        post[:merchantId] = @options[:merchant_id]
        post[:merchantSiteId] = @options[:merchant_site_id]
        post[:timeStamp] = current_timestamp.to_i
        post[:clientRequestId] = SecureRandom.uuid
        post[:clientUniqueId] = options[:order_id] || generate_unique_id
      end

      def calculate_checksum(post, action)
        common_keys = %i[merchantId merchantSiteId clientRequestId]
        keys = case action
               when :authenticate
                 [:timeStamp]
               when :capture, :refund, :void
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
          error_code: error_code_from(response)
        )
      end

      def fetch_session_token(post = {})
        build_post_data(post)
        send_session_request(post)
      end

      def session_token_valid?
        return false unless @options[:session_token] && @options[:token_expires]

        (Time.now.utc.to_i - @options[:token_expires].to_i) < 900 # 15 minutes
      end

      def commit(action, post, authorization = nil, method = :post)
        post[:sessionToken] = @options[:session_token] unless %i(capture refund).include?(action)
        post[:checksum] = calculate_checksum(post, action)

        response = parse(ssl_request(method, url(action, authorization), post.to_json, headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response, post),
          network_transaction_id: network_transaction_id_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        @options[:session_token] = '' if e.response.code == '401'

        Response.new(false, message_from(response), response, test: test?)
      end

      def url(action, id = nil)
        "#{test? ? test_url : live_url}#{ENDPOINTS_MAPPING[action] % id}"
      end

      def error_code_from(response)
        response[:errCode] == 0 ? response[:gwErrorCode] : response[:errCode]
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
        response[:status] == 'SUCCESS' && %w[APPROVED REDIRECT PENDING].include?(response[:transactionStatus])
      end

      def authorization_from(action, response, post)
        if zero_auth?(post)
          response.dig(:paymentOption, :userPaymentOptionId)
        else
          response[:transactionId]
        end
      end

      def zero_auth?(post)
        post[:userTokenId].present? && post[:transactionType] == 'Auth' && post[:amount].to_i == 0
      end

      def message_from(response)
        reason = response[:reason]&.present? ? response[:reason] : nil
        response[:gwErrorReason] || reason || response[:transactionStatus]
      end
    end
  end
end
