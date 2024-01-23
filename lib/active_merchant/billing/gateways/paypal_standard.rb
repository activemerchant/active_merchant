module ActiveMerchant
  module Billing
    class PaypalStandardGateway < Gateway
      self.test_url = 'https://api-m.sandbox.paypal.com'
      self.live_url = 'https://api-m.paypal.com'
      self.supported_countries = %w[AL DZ AD AO AI AG AR AM AW AU AT AZ BS BH BB BY BE BZ BJ BM BT BO BA BW BR VG BN BG BF BI KH CM CA CV KY TD CL CO KM CG CD CK CR CI HR CY CZ DK DJ DM DO EC EG SV ER EE ET FK FO FJ FI FR GF PF GA GM GE DE GI GR GL GD GP GT GN GW GY HN HK HU IS IN ID IE IL IT JM JP JO KZ KE KI KW KG LA LV LS LI LT LU MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ NA NR NP NL NC NZ NI NE NG NU NF NO OM PW PA PG PY PE PH PN PL PT QA RE RO RU RW WS SM ST SA SN RS SC SL SG SK SI SB SO ZA KR ES LK SH KN LC PM VC SR SJ SZ SE CH TW TJ TZ TH TG TO TT TN TM TC TV UG UA AE GB US UY VU VA VE VN WF YE ZM ZW].freeze
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express diners_club maestro discover jcb mada bp_plus]
      self.display_name = 'PayPal'

      ENDPOINTS = {
        generate_token: '/v1/oauth2/token',
        create_order: '/v2/checkout/orders',
        capture_order: '/v2/checkout/orders/%{id}/capture',
        refund: '/v2/payments/captures/%{id}/refund'
      }

      SOFT_DECLINE_CODES = %w[INVALID_REQUEST AUTHENTICATION_FAILURE UNPROCESSABLE_ENTITY RATE_LIMIT_REACHED].freeze
      SUCCESS_CODES = %w[COMPLETED].freeze

      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        @client_id = options[:client_id]
        @client_secret = options[:client_secret]
        @response_http_code = nil

        super
        @access_token = setup_access_token
        @request_id = SecureRandom.uuid
      end

      def purchase(amount, payment_method, options = {})
        post ||= {}

        amount = to_currency(amount)

        add_payment_intent(post)
        add_purchase_units(post, amount, options)
        add_payment_source(post, payment_method, options)

        commit(:create_order, post)
      end

      def capture(authorization, options = {})
        post = {}

        commit(:capture_order, post, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}

        amount = to_currency(amount)

        add_refund_amount(post, amount, options)
        add_refund_reason(post, options)

        commit(:refund, post, authorization)
      end

      private

      def commit(action, post, id = nil)
        begin
          url = build_request_url(action, id)
          response = parse(ssl_post(url, post_data(post), headers))
          succeeded = success_from(response)
        rescue ResponseError => e
          response = parse(e.response.body, error: e.response)
        end

        Response.new(
          succeeded,
          message_from(succeeded, response),
          normalize_response(action, response),
          test: test?,
          authorization: authorization_from(action, response),
          error_code: succeeded ? nil : error_code_from(response),
          avs_result: { code: response['avs'] },
          cvv_result: response['cvv2'],
          response_type: response_type(action, response),
          response_http_code: @response_http_code,
          request_endpoint: url,
          request_method: request_method(action),
          request_body: post,
          request_id: @request_id
        )
      end

      def base_url
        if test?
          test_url
        else
          live_url
        end
      end

      def normalize_response(action, response)
        if action == :create_order && response.present?
          redirect_link = response['links'].find { |link| link['rel'] == 'payer-action' }
          response['_links'] = { 'redirect' => { 'href' => redirect_link['href'] } } if redirect_link
          response['order_id'] = response['id']
        end
        response
      end

      def request_method(action)
        case action
        when :generate_token, :create_order, :capture_order, :refund
          'post'
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
        { 'Authorization' => "Bearer #{@access_token}", 'Content-Type' => 'application/json', 'PayPal-Request-Id' => @request_id }
      end

      def post_data(post)
        post.to_json
      end

      def parse(body, error: nil)
        JSON.parse(body)
      rescue JSON::ParserError
        response = {
          'error_type' => error&.code,
          'message' => 'Invalid JSON response received from Paypal.com Unified Payments Gateway. Please contact Paypal.com if you continue to receive this message.'
        }

        response['error_codes'] = [error&.message] if error&.message
        response
      end

      def grant_type
        'grant_type=client_credentials'
      end

      def success_from(response)
        SUCCESS_CODES.include?(response['status'])
      end

      def message_from(succeeded, response)
        if succeeded
          response['status']
        elsif response['message']
          response['name'] + ': ' + response['message']
        else
          response['error'] || response['error_description'] || response['status'] || response['message'] || 'Unable to read error message'
        end
      end

      def authorization_from(action, response)
        case action
        when :create_order, :refund_order
          response.dig('id')
        when :capture_order
          purchase_unit = response.dig('purchase_units', 0)
          captures = purchase_unit&.dig('payments', 'captures', 0)
          captures&.dig('id')
        end
      end

      def error_code_from(response)
        response['name'] unless success_from(response)
      end

      def add_purchase_units(post, amount, options)
        purchase_unit = {}
        purchase_unit[:reference_id] = options[:order_id]
        purchase_unit[:amount] = {}
        purchase_unit[:amount][:value] = amount
        purchase_unit[:amount][:currency_code] = options[:currency]
        add_shipping_address(purchase_unit, options)

        post[:purchase_units] ||= []
        post[:purchase_units] << purchase_unit
      end

      def add_payment_source(post, payment_method, options)
        post[:payment_source] = {}
        redirect_links = options[:redirect_links]

        case payment_method.paypal_method_type
        when 'paypal'
          payment_source = post[:payment_source][:paypal] = {}
          experience_context = payment_source[:experience_context] = {}

          experience_context[:landing_page] = 'LOGIN'
          experience_context[:user_action] = 'PAY_NOW'
          experience_context[:return_url] = redirect_links[:success_url] if redirect_links
          experience_context[:cancel_url] = redirect_links[:failure_url] if redirect_links
        when 'giropay'
          payment_source = post[:payment_source][:giropay] = {}

          add_payment_source_details(payment_source, redirect_links, options)
        when 'sofort'
          payment_source = post[:payment_source][:sofort] = {}

          add_payment_source_details(payment_source, redirect_links, options)
        end
      end

      def add_shipping_address(purchase_unit, options)
        purchase_unit[:shipping] = {}
        purchase_unit[:shipping][:address] = {}
        purchase_unit[:shipping][:address][:address_line_1] = options[:billing_address][:address1]
        purchase_unit[:shipping][:address][:admin_area_2] = options[:billing_address][:city]
        purchase_unit[:shipping][:address][:admin_area_1] = options[:billing_address][:state]
        purchase_unit[:shipping][:address][:postal_code] = options[:billing_address][:zip]
        purchase_unit[:shipping][:address][:country_code] = options[:billing_address][:country]
      end

      def add_payment_source_details(payment_source, redirect_links, options)
        payment_source[:name] = options[:billing_address] ? options[:billing_address][:name] : ''
        payment_source[:country_code] = options[:billing_address] ? options[:billing_address][:country] : ''

        payment_source[:experience_context] = {}
        payment_source[:experience_context][:brand_name] = options[:campaign_name]
        payment_source[:experience_context][:return_url] = redirect_links[:success_url] if redirect_links
        payment_source[:experience_context][:cancel_url] = redirect_links[:failure_url] if redirect_links
      end

      def add_payment_intent(post)
        post[:intent] = 'CAPTURE'
      end

      def add_refund_amount(post, amount, options)
        post[:amount] = {
          "value": amount,
          "currency_code": options[:currency]
        }
      end

      def add_refund_reason(post, options)
        post[:note_to_payer] = options[:refund_reason]
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        super
      end

      def response_type(action, response)
        return unless action == :capture_order

        if SUCCESS_CODES.include?(response['status'])
          0
        elsif SOFT_DECLINE_CODES.include?(response['name'])
          1
        else
          2
        end
      end

      def to_currency(amount)
        dollars = amount.to_f / 100.0
        sprintf('%.2f', dollars)
      end
    end
  end
end
