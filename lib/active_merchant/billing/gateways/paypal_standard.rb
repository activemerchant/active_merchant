module ActiveMerchant
  module Billing
    class PaypalStandardGateway < Gateway
      include Empty
      self.test_url = 'https://api-m.sandbox.paypal.com'
      self.live_url = 'https://api-m.paypal.com'
      self.supported_countries = %w[AL DZ AD AO AI AG AR AM AW AU AT AZ BS BH BB BY BE BZ BJ BM BT BO BA BW BR VG BN BG BF BI KH CM CA CV KY TD CL C2 CO KM CG CD CK CR CI HR CY CZ DK DJ DM DO EC EG SV ER EE ET FK FO FJ FI FR GF PF GA GM GE DE GI GR GL GD GP GT GN GW GY HN HK HU IS IN ID IE IL IT JM JP JO KZ KE KI KW KG LA LV LS LI LT LU MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ NA NR NP NL NC NZ NI NE NG NU NF NO OM PW PA PG PY PE PH PN PL PT QA RE RO RU RW WS SM ST SA SN RS SC SL SG SK SI SB SO ZA KR ES LK SH KN LC PM VC SR SJ SZ SE CH TW TJ TZ TH TG TO TT TN TM TC TV UG UA AE GB US UY VU VA VE VN WF YE ZM ZW].freeze      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express diners_club maestro discover jcb mada bp_plus]
      self.display_name = 'PayPal'

      ENDPOINTS = {
        generate_token: '/v1/oauth2/token',
        create_order: '/v2/checkout/orders',
        capture_order: '/v2/checkout/orders/%{id}/capture',
        refund: '/v2/payments/captures/%{id}/refund'
      }

      SOFT_DECLINE_CODES = [].freeze
      HARD_DECLINE_CODES = %w[CARD_EXPIRED TRANSACTION_BLOCKED_BY_PAYEE PAYER_ACCOUNT_LOCKED_OR_CLOSED]

      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        @client_id = options[:client_id]
        @client_secret = options[:client_secret]
        @response_http_code = nil

        super
        @access_token = setup_access_token
      end

      def purchase(amount, payment_method, options = {})
        post ||= {}

        add_payment_intent(post, intent_type = "CAPTURE")
        add_purchase_units(post, amount, options)
        add_payment_source(post, options)

        commit(:create_order, post)
      end

      def capture(amount, authorization, options = {})
        post = {}

        commit(:capture_order, post, options[:order_id])
      end

      def refund(amount, authorization, options = {})
        post = {}

        add_refund_amount(post, amount, options) unless options[:full_refund].present?
        add_refund_reason(post, options)

        commit(:refund, post, options[:capture_id])
      end

      private

      def commit(action, post, id = nil)
        url = build_request_url(action, id)

        response = parse(ssl_post(url, post_data(post), headers))
        success = success_from(response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?,
          authorization: authorization_from(response),
          avs_result: { code: response['avs'] },
          cvv_result: response['cvv2'],
          error_code: success ? nil : error_code_from(response)
        )
      end

      def base_url
        if test?
          test_url
        else
          live_url
        end
      end

      def setup_access_token
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{encoded_credentials}"
        }

        response = ssl_post(build_request_url(:generate_token), grant_type, headers)
        JSON.parse(response)['access_token']
      end

      def build_request_url(action, id = nil)
        base_url = (test? ? test_url : live_url)
        base_url + ENDPOINTS[action].to_s % { id: id }
      end

      def encoded_credentials
        Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      end

      def headers
       { 'Authorization' => "Bearer #{@access_token}", 'Content-Type' => 'application/json' }
      end

      def post_data(post)
        post.to_json
      end

      def grant_type
        "grant_type=client_credentials"
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response["status"] == "CREATED"
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

      def add_purchase_units(post, amount, options)
        purchase_unit = {}
        purchase_unit[:amount] = {}
        purchase_unit[:amount][:value] = amount
        purchase_unit[:amount][:currency_code] = options[:currency_code]

        post[:purchase_units] ||= []

        post[:purchase_units] << purchase_unit
      end

      def add_payment_source(post, options)
        post[:payment_source] ||= {}
        post[:payment_source][:paypal] ||= {}

        payment_source = {}
        payment_source[:landing_page] = "LOGIN"
        payment_source[:user_action] = "PAY_NOW"
        payment_source[:return_url] = options[:return_url]
        payment_source[:cancel_url] = options[:cancel_url]
        post[:payment_source][:paypal][:experience_context] = payment_source
      end

      def add_payment_intent(post, intent_type = "CAPTURE")
        post[:intent] = intent_type
      end

      def add_refund_amount(post, amount, options)
        post[:amount] = {
          "value": amount,
          "currency_code": options[:currency_code]
        }
      end

      def add_refund_reason(post, options)
        post[:note_to_payer] = options[:refund_reason]
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        super
      end
    end
  end
end
