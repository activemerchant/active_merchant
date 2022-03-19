module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AirwallexGateway < Gateway
      self.test_url = 'https://api-demo.airwallex.com/api/v1'
      self.live_url = 'https://pci-api.airwallex.com/api/v1'

      # per https://www.airwallex.com/docs/online-payments__overview, cards are accepted in all EU countries
      self.supported_countries = %w[AT AU BE BG CY CZ DE DK EE GR ES FI FR GB HK HR HU IE IT LT LU LV MT NL PL PT RO SE SG SI SK]
      self.default_currency = 'AUD'
      self.supported_cardtypes = %i[visa master]

      self.homepage_url = 'https://airwallex.com/'
      self.display_name = 'Airwallex'

      ENDPOINTS = {
        login: '/authentication/login',
        setup: '/pa/payment_intents/create',
        sale: '/pa/payment_intents/%{id}/confirm',
        capture: '/pa/payment_intents/%{id}/capture',
        refund: '/pa/refunds/create',
        void: '/pa/payment_intents/%{id}/cancel'
      }

      def initialize(options = {})
        requires!(options, :client_id, :client_api_key)
        @client_id = options[:client_id]
        @client_api_key = options[:client_api_key]
        super
        setup_ids(options) unless options[:request_id] && options[:merchant_order_id]
        @access_token = setup_access_token
      end

      def purchase(money, card, options = {})
        requires!(options, :return_url)
        payment_intent_id = create_payment_intent(money, @options)
        post = {
          'request_id' => update_request_id(@options, 'purchase'),
          'return_url' => options[:return_url]
        }
        add_card(post, card, options)
        post['payment_method_options'] = { 'card' => { 'auto_capture' => false } } if authorization_only?(options)

        commit(:sale, post, payment_intent_id)
      end

      def authorize(money, payment, options = {})
        # authorize is just a purchase w/o an auto capture
        purchase(money, payment, options.merge({ auto_capture: false }))
      end

      def capture(money, authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        update_request_id(@options, 'capture')
        post = {
          'request_id' => @options[:request_id],
          'amount' => amount(money)
        }
        commit(:capture, post, authorization)
      end

      def refund(money, authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        post = {}
        post[:amount] = amount(money)
        post[:payment_intent_id] = authorization
        post[:request_id] = update_request_id(@options, 'refund')
        post[:merchant_order_id] = @options[:merchant_order_id]

        commit(:refund, post)
      end

      def void(authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        update_request_id(@options, 'void')
        post = {}
        post[:request_id] = @options[:request_id]
        commit(:void, post, authorization)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(\\\"number\\\":\\\")\d+/, '\1[REDACTED]').
          gsub(/(\\\"cvc\\\":\\\")\d+/, '\1[REDACTED]')
      end

      private

      def setup_ids(options)
        request_id, merchant_order_id = generate_ids
        options[:request_id] = options[:request_id] || request_id
        options[:merchant_order_id] = options[:merchant_order_id] || merchant_order_id
      end

      def generate_ids
        timestamp = (Time.now.to_f.round(2) * 100).to_i.to_s
        [timestamp.to_s, "mid_#{timestamp}"]
      end

      def setup_access_token
        token_headers = {
          'Content-Type' => 'application/json',
          'x-client-id' => @client_id,
          'x-api-key' => @client_api_key
        }
        response = ssl_post(build_request_url(:login), nil, token_headers)
        JSON.parse(response)['token']
      end

      def build_request_url(action, id = nil)
        base_url = (test? ? test_url : live_url)
        base_url + ENDPOINTS[action].to_s % { id: id }
      end

      def create_payment_intent(money, options = {})
        post = {}
        add_invoice(post, money, options)
        post[:request_id] = options[:request_id]
        post[:merchant_order_id] = options[:merchant_order_id]

        response = commit(:setup, post)
        response.params['id']
      end

      def add_billing(post, card, options = {})
        return unless card_has_billing_info(card, options)

        billing = post['payment_method']['card']['billing'] || {}
        billing['email'] = options[:email] if options[:email]
        billing['phone'] = options[:phone] if options[:phone]
        billing['first_name'] = card.first_name
        billing['last_name'] = card.last_name
        billing['address'] = add_address(card, options) if card_has_address_info(card, options)

        post['payment_method']['card']['billing'] = billing
      end

      def card_has_billing_info(card, options)
        # These fields are required if billing data is sent.
        card.first_name && card.last_name
      end

      def card_has_address_info(card, options)
        # These fields are required if address data is sent.
        options[:address1] && options[:country]
      end

      def add_address(card, options = {})
        address = {}
        address[:country_code] = options[:country]
        address[:street] = options[:address1]
        address[:city] = options[:city] if options[:city] # required per doc, not in practice
        address[:postcode] = options[:zip] if options[:zip]
        address[:state] = options[:state] if options[:state]
        address
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_card(post, card, options = {})
        post['payment_method'] = {
          'type' => 'card',
          'card' => {
            'expiry_month' => format(card.month, :two_digits),
            'expiry_year' => card.year.to_s,
            'number' => card.number.to_s,
            'name' => card.name,
            'cvc' => card.verification_value
          }
        }
        add_billing(post, card, options)
      end

      def authorization_only?(options = {})
        options.include?(:auto_capture) && options[:auto_capture] == false
      end

      def update_request_id(options, action)
        options[:request_id] += "_#{action}"
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, post, id = nil)
        url = build_request_url(action, id)
        post_headers = { 'Authorization' => "Bearer #{@access_token}", 'Content-Type' => 'application/json' }
        response = parse(ssl_post(url, post_data(post), post_headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 404
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def post_data(post)
        post.to_json
      end

      def success_from(response)
        %w(REQUIRES_PAYMENT_METHOD SUCCEEDED RECEIVED REQUIRES_CAPTURE CANCELLED).include?(response['status'])
      end

      def message_from(response)
        response.dig('latest_payment_attempt', 'status') || response['status'] || response['message']
      end

      def authorization_from(response)
        response.dig('latest_payment_attempt', 'payment_intent_id')
      end

      def error_code_from(response)
        response['provider_original_response_code'] || response['code'] unless success_from(response)
      end
    end
  end
end
