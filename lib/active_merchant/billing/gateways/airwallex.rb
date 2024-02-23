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

      # Provided by Airwallex for testing purposes
      TEST_NETWORK_TRANSACTION_IDS = {
        visa: '123456789012345',
        master: 'MCC123ABC0101'
      }

      def initialize(options = {})
        requires!(options, :client_id, :client_api_key)
        @client_id = options[:client_id]
        @client_api_key = options[:client_api_key]
        super
        @access_token = options[:access_token] || setup_access_token
      end

      def purchase(money, card, options = {})
        payment_intent_id = create_payment_intent(money, options)
        post = {
          'request_id' => request_id(options),
          'merchant_order_id' => merchant_order_id(options)
        }
        add_card(post, card, options)
        add_descriptor(post, options)
        add_stored_credential(post, options)
        add_return_url(post, options)
        post['payment_method_options'] = { 'card' => { 'auto_capture' => false } } if authorization_only?(options)

        add_three_ds(post, options)
        commit(:sale, post, payment_intent_id)
      end

      def authorize(money, payment, options = {})
        # authorize is just a purchase w/o an auto capture
        purchase(money, payment, options.merge({ auto_capture: false }))
      end

      def capture(money, authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        post = {
          'request_id' => request_id(options),
          'merchant_order_id' => merchant_order_id(options),
          'amount' => amount(money)
        }
        add_descriptor(post, options)

        commit(:capture, post, authorization)
      end

      def refund(money, authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        post = {}
        post[:amount] = amount(money)
        post[:payment_intent_id] = authorization
        post[:request_id] = request_id(options)
        post[:merchant_order_id] = merchant_order_id(options)

        commit(:refund, post)
      end

      def void(authorization, options = {})
        raise ArgumentError, 'An authorization value must be provided.' if authorization.blank?

        post = {}
        post[:request_id] = request_id(options)
        post[:merchant_order_id] = merchant_order_id(options)
        add_descriptor(post, options)

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
          gsub(/(\\"number\\":\\")\d+/, '\1[REDACTED]').
          gsub(/(\\"cvc\\":\\")\d+/, '\1[REDACTED]')
      end

      private

      def request_id(options)
        options[:request_id] || generate_uuid
      end

      def merchant_order_id(options)
        options[:merchant_order_id] || options[:order_id] || generate_uuid
      end

      def add_return_url(post, options)
        post[:return_url] = options[:return_url] if options[:return_url]
      end

      def generate_uuid
        SecureRandom.uuid
      end

      def setup_access_token
        token_headers = {
          'Content-Type' => 'application/json',
          'x-client-id' => @client_id,
          'x-api-key' => @client_api_key
        }

        begin
          raw_response = ssl_post(build_request_url(:login), nil, token_headers)
        rescue ResponseError => e
          raise OAuthResponseError.new(e)
        else
          response = JSON.parse(raw_response)
          if (token = response['token'])
            token
          else
            oauth_response = Response.new(false, response['message'])
            raise OAuthResponseError.new(oauth_response)
          end
        end
      end

      def build_request_url(action, id = nil)
        base_url = (test? ? test_url : live_url)
        endpoint = ENDPOINTS[action].to_s
        endpoint = id.present? ? endpoint % { id: id } : endpoint
        base_url + endpoint
      end

      def add_referrer_data(post)
        post[:referrer_data] = { type: 'spreedly' }
      end

      def create_payment_intent(money, options = {})
        post = {}
        add_invoice(post, money, options)
        add_order(post, options)
        post[:request_id] = "#{request_id(options)}_setup"
        post[:merchant_order_id] = merchant_order_id(options)
        add_referrer_data(post)
        add_descriptor(post, options)
        post['payment_method_options'] = { 'card' => { 'risk_control' => { 'three_ds_action' => 'SKIP_3DS' } } } if options[:skip_3ds]

        response = commit(:setup, post)
        raise ArgumentError.new(response.message) unless response.success?

        response.params['id']
      end

      def add_billing(post, card, options = {})
        return unless has_name_info?(card)

        billing = post['payment_method']['card']['billing'] || {}
        billing['email'] = options[:email] if options[:email]
        billing['phone'] = options[:phone] if options[:phone]
        billing['first_name'] = card.first_name
        billing['last_name'] = card.last_name
        billing_address = options[:billing_address]
        billing['address'] = build_address(billing_address) if has_required_address_info?(billing_address)

        post['payment_method']['card']['billing'] = billing
      end

      def has_name_info?(card)
        # These fields are required if billing data is sent.
        card.first_name && card.last_name
      end

      def has_required_address_info?(address)
        # These fields are required if address data is sent.
        return unless address

        address[:address1] && address[:country]
      end

      def build_address(address)
        return unless address

        address_data = {} # names r hard
        address_data[:country_code] = address[:country]
        address_data[:street] = address[:address1]
        address_data[:city] = address[:city] if address[:city] # required per doc, not in practice
        address_data[:postcode] = address[:zip] if address[:zip]
        address_data[:state] = address[:state] if address[:state]
        address_data
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
            'cvc' => card.verification_value,
            'brand' => card.brand
          }
        }
        add_billing(post, card, options)
      end

      def add_order(post, options)
        return unless shipping_address = options[:shipping_address]

        physical_address = build_shipping_address(shipping_address)
        first_name, last_name = split_names(shipping_address[:name])
        shipping = {}
        shipping[:first_name] = first_name if first_name
        shipping[:last_name] = last_name if last_name
        shipping[:phone_number] = shipping_address[:phone_number] if shipping_address[:phone_number]
        shipping[:address] = physical_address
        post[:order] = { shipping: shipping }
      end

      def build_shipping_address(shipping_address)
        address = {}
        address[:city] = shipping_address[:city]
        address[:country_code] = shipping_address[:country]
        address[:postcode] = shipping_address[:zip]
        address[:state] = shipping_address[:state]
        address[:street] = shipping_address[:address1]
        address
      end

      def add_stored_credential(post, options)
        return unless stored_credential = options[:stored_credential]

        external_recurring_data = post[:external_recurring_data] = {}

        case stored_credential.dig(:reason_type)
        when 'recurring', 'installment'
          external_recurring_data[:merchant_trigger_reason] = 'scheduled'
        when 'unscheduled'
          external_recurring_data[:merchant_trigger_reason] = 'unscheduled'
        end

        external_recurring_data[:original_transaction_id] = test_mit?(options) ? test_network_transaction_id(post) : stored_credential.dig(:network_transaction_id)
        external_recurring_data[:triggered_by] = stored_credential.dig(:initiator) == 'cardholder' ? 'customer' : 'merchant'
      end

      def test_network_transaction_id(post)
        case post['payment_method']['card']['brand']
        when 'visa'
          TEST_NETWORK_TRANSACTION_IDS[:visa]
        when 'master'
          TEST_NETWORK_TRANSACTION_IDS[:master]
        end
      end

      def test_mit?(options)
        test? && options.dig(:stored_credential, :initiator) == 'merchant'
      end

      def add_three_ds(post, options)
        return unless three_d_secure = options[:three_d_secure]

        pm_options = post.dig('payment_method_options', 'card')

        external_three_ds = {
          version: format_three_ds_version(three_d_secure),
          eci: three_d_secure[:eci]
        }.merge(three_ds_version_specific_fields(three_d_secure))

        pm_options ? pm_options.merge!(external_three_ds: external_three_ds) : post['payment_method_options'] = { card: { external_three_ds: external_three_ds } }
      end

      def format_three_ds_version(three_d_secure)
        version = three_d_secure[:version].split('.')

        version.push('0') until version.length == 3
        version.join('.')
      end

      def three_ds_version_specific_fields(three_d_secure)
        if three_d_secure[:version].to_f >= 2
          {
            authentication_value: three_d_secure[:cavv],
            ds_transaction_id: three_d_secure[:ds_transaction_id],
            three_ds_server_transaction_id: three_d_secure[:three_ds_server_trans_id]
          }
        else
          {
            cavv: three_d_secure[:cavv],
            xid: three_d_secure[:xid]
          }
        end
      end

      def authorization_only?(options = {})
        options.include?(:auto_capture) && options[:auto_capture] == false
      end

      def add_descriptor(post, options)
        post[:descriptor] = options[:description] if options[:description]
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
          avs_result: AVSResult.new(code: response.dig('latest_payment_attempt', 'authentication_data', 'avs_result')),
          cvv_result: CVVResult.new(response.dig('latest_payment_attempt', 'authentication_data', 'cvc_code')),
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
