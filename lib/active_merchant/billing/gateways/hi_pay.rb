module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class HiPayGateway < Gateway
      # to add more check => payment_product_list: https://developer.hipay.com/api-explorer/api-online-payments#/payments/generateHostedPaymentPage
      PAYMENT_PRODUCT = {
        'visa' => 'visa',
        'master' => 'mastercard'
      }

      DEVICE_CHANEL = {
        app: 1,
        browser:  2,
        three_ds_requestor_initiaded:  3
      }

      self.test_url = 'https://stage-secure-gateway.hipay-tpp.com/rest'
      self.live_url = 'https://secure-gateway.hipay-tpp.com/rest'

      self.supported_countries = %w[FR]
      self.default_currency = 'EUR'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'https://hipay.com/'
      self.display_name = 'HiPay'

      def initialize(options = {})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        super
      end

      def purchase(money, payment_method, options = {})
        authorize(money, payment_method, options.merge({ operation: 'Sale' }))
      end

      def authorize(money, payment_method, options = {})
        MultiResponse.run do |r|
          if payment_method.is_a?(CreditCard)
            response = r.process { tokenize(payment_method, options) }
            card_token = response.params['token']
          elsif payment_method.is_a?(String)
            _transaction_ref, card_token, payment_product = payment_method.split('|') if payment_method.split('|').size == 3
            card_token, payment_product = payment_method.split('|') if payment_method.split('|').size == 2
          end

          payment_product = payment_method.is_a?(CreditCard) ? PAYMENT_PRODUCT[payment_method.brand] : PAYMENT_PRODUCT[payment_product&.downcase]

          post = {
            payment_product:,
            operation: options[:operation] || 'Authorization',
            cardtoken: card_token
          }
          add_address(post, options)
          add_product_data(post, options)
          add_invoice(post, money, options)
          add_3ds(post, options)
          r.process { commit('order', post) }
        end
      end

      def capture(money, authorization, options)
        reference_operation(money, authorization, options.merge({ operation: 'capture' }))
      end

      def store(payment_method, options = {})
        tokenize(payment_method, options.merge({ multiuse: '1' }))
      end

      def unstore(authorization, options = {})
        _transaction_ref, card_token, _payment_product = authorization.split('|') if authorization.split('|').size == 3
        card_token, _payment_product = authorization.split('|') if authorization.split('|').size == 2
        commit('unstore', { card_token: }, options, :delete)
      end

      def refund(money, authorization, options)
        reference_operation(money, authorization, options.merge({ operation: 'refund' }))
      end

      def void(authorization, options)
        reference_operation(nil, authorization, options.merge({ operation: 'cancel' }))
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )[\w =]+), '\1[FILTERED]').
          gsub(%r((card_number=)\w+), '\1[FILTERED]\2').
          gsub(%r((cvc=)\w+), '\1[FILTERED]\2')
      end

      private

      def reference_operation(money, authorization, options)
        post = {}
        post[:operation] = options[:operation]
        post[:currency] = (options[:currency] || currency(money))
        post[:amount] = amount(money) if options[:operation] == 'refund' || options[:operation] == 'capture'
        commit(options[:operation], post, { transaction_reference: authorization.split('|').first })
      end

      def add_product_data(post, options)
        post[:orderid] = options[:order_id] if options[:order_id]
        post[:description] = options[:description]
      end

      def add_invoice(post, money, options)
        post[:currency] = (options[:currency] || currency(money))
        post[:amount] = amount(money)
      end

      def add_credit_card(post, credit_card)
        post[:card_number] = credit_card.number
        post[:card_expiry_month] = credit_card.month
        post[:card_expiry_year] = credit_card.year
        post[:card_holder] = credit_card.name
        post[:cvc] = credit_card.verification_value
      end

      def add_address(post, options)
        return unless billing_address = options[:billing_address]

        post[:streetaddress] = billing_address[:address1] if billing_address[:address1]
        post[:streetaddress2] = billing_address[:address2] if billing_address[:address2]
        post[:city] = billing_address[:city] if billing_address[:city]
        post[:recipient_info] = billing_address[:company] if billing_address[:company]
        post[:state] = billing_address[:state] if billing_address[:state]
        post[:country] = billing_address[:country] if billing_address[:country]
        post[:zipcode] = billing_address[:zip] if billing_address[:zip]
        post[:country] = billing_address[:country] if billing_address[:country]
        post[:phone] = billing_address[:phone] if billing_address[:phone]
      end

      def tokenize(payment_method, options = {})
        post = {}
        add_credit_card(post, payment_method)
        post[:multi_use] = options[:multiuse] ? '1' : '0'
        post[:generate_request_id] = '0'
        commit('store', post, options)
      end

      def add_3ds(post, options)
        return unless options[:execute_threed] && options[:three_ds_2]

        browser_info_3ds = options[:three_ds_2][:browser_info]

        browser_info_hash = {
          java_enabled: browser_info_3ds[:java],
            javascript_enabled: (browser_info_3ds[:javascript] || false),
            ipaddr:  options[:ip],
            http_accept: '*\\/*',
            http_user_agent: browser_info_3ds[:user_agent],
            language: browser_info_3ds[:language],
            color_depth: browser_info_3ds[:depth],
            screen_height:   browser_info_3ds[:height],
            screen_width: browser_info_3ds[:width],
            timezone: browser_info_3ds[:timezone]
        }

        browser_info_hash['device_fingerprint'] = options[:device_fingerprint] if options[:device_fingerprint]
        post[:browser_info] = browser_info_hash.to_json
        post.to_json

        post[:accept_url] = options[:accept_url] if options[:accept_url]
        post[:decline_url] = options[:decline_url] if options[:decline_url]
        post[:pending_url] = options[:pending_url] if options[:pending_url]
        post[:exception_url] = options[:exception_url] if options[:exception_url]
        post[:cancel_url] = options[:cancel_url] if options[:cancel_url]
        post[:notify_url] = browser_info_3ds[:notification_url] if browser_info_3ds[:notification_url]
        post[:authentication_indicator] = DEVICE_CHANEL[options[:three_ds_2][:channel]] || 0
      end

      def parse(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def commit(action, post, options = {}, method = :post)
        raw_response = begin
          ssl_request(method, url(action, options), post_data(post), request_headers)
        rescue ResponseError => e
          e.response.body
        end

        response = parse(raw_response)

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def error_code_from(action, response)
        (response['code'] || response.dig('reason', 'code')).to_s unless success_from(action, response)
      end

      def success_from(action, response)
        case action
        when 'order'
          response['state'] == 'completed' || (response['state'] == 'forwarding' && response['status'] == '140')
        when 'capture'
          response['status'] == '118' && response['message'] == 'Captured'
        when 'refund'
          response['status'] == '124' && response['message'] == 'Refund Requested'
        when 'cancel'
          response['status'] == '175' && response['message'] == 'Authorization Cancellation requested'
        when 'store'
          response.include? 'token'
        when 'unstore'
          response['code'] == '204'
        else
          false
        end
      end

      def message_from(action, response)
        response['message']
      end

      def authorization_from(action, response)
        authorization_string(response['transactionReference'], response['token'], response['brand'])
      end

      def authorization_string(*args)
        args.flatten.compact.reject(&:empty?).join('|')
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url(action, options = {})
        case action
        when 'store'
          "#{token_url}/create"
        when 'unstore'
          token_url
        when 'capture', 'refund', 'cancel'
          endpoint = "maintenance/transaction/#{options[:transaction_reference]}"
          base_url(endpoint)
        else
          base_url(action)
        end
      end

      def base_url(endpoint)
        "#{test? ? test_url : live_url}/v1/#{endpoint}"
      end

      def token_url
        "https://#{'stage-' if test?}secure2-vault.hipay-tpp.com/rest/v2/token"
      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def handle_response(response)
        case response.code.to_i
        # to get the response code after unstore(delete instrument), because the body is nil
        when 200...300
          response.body || { code: response.code }.to_json
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
