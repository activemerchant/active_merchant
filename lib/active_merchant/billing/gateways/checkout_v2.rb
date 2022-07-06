module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutV2Gateway < Gateway
      self.display_name = 'Checkout.com Unified Payments'
      self.homepage_url = 'https://www.checkout.com/'
      self.live_url = 'https://api.checkout.com'
      self.test_url = 'https://api.sandbox.checkout.com'

      self.supported_countries = %w[AD AE AR AT AU BE BG BH BR CH CL CN CO CY CZ DE DK EE EG ES FI FR GB GR HK HR HU IE IS IT JO JP KW LI LT LU LV MC MT MX MY NL NO NZ OM PE PL PT QA RO SA SE SG SI SK SM TR US]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express diners_club maestro discover jcb mada]
      self.currencies_without_fractions = %w(BIF DJF GNF ISK KMF XAF CLF XPF JPY PYG RWF KRW VUV VND XOF)
      self.currencies_with_three_decimal_places = %w(BHD LYD JOD KWD OMR TND)

      LIVE_ACCESS_TOKEN_URL = 'https://access.checkout.com/connect/token'
      TEST_ACCESS_TOKEN_URL = 'https://access.sandbox.checkout.com/connect/token'

      def initialize(options = {})
        @options = options
        @access_token = nil
        begin
          requires!(options, :secret_key)
        rescue ArgumentError
          requires!(options, :client_id, :client_secret)
          @access_token = setup_access_token
        end
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        build_auth_or_purchase(post, amount, payment_method, options)

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        post[:capture] = false
        build_auth_or_purchase(post, amount, payment_method, options)

        options[:incremental_authorization].to_s.casecmp('true').zero? ? commit(:incremental_authorize, post, payment_method) : commit(:authorize, post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        post[:capture_type] = options[:capture_type] || 'Final'
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit(:capture, post, authorization)
      end

      def void(authorization, _options = {})
        post = {}
        add_metadata(post, options)

        commit(:void, post, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit(:refund, post, authorization)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
      end

      def verify_payment(authorization, option = {})
        commit(:verify_payment, authorization)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: )[^\\]*/i, '\1[FILTERED]').
          gsub(/("number\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("cvv\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("cryptogram\\":\\")\w+/, '\1[FILTERED]').
          gsub(/(source\\":\{.*\\"token\\":\\")\d+/, '\1[FILTERED]')
      end

      private

      def build_auth_or_purchase(post, amount, payment_method, options)
        add_invoice(post, amount, options)
        add_authorization_type(post, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_stored_credential_options(post, options)
        add_transaction_data(post, options)
        add_3ds(post, options)
        add_metadata(post, options, payment_method)
        add_processing_channel(post, options)
        add_marketplace_data(post, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = localized_amount(money, options[:currency])
        post[:reference] = options[:order_id]
        post[:currency] = options[:currency] || currency(money)
        if options[:descriptor_name] || options[:descriptor_city]
          post[:billing_descriptor] = {}
          post[:billing_descriptor][:name] = options[:descriptor_name] if options[:descriptor_name]
          post[:billing_descriptor][:city] = options[:descriptor_city] if options[:descriptor_city]
        end
        post[:metadata] = {}
        post[:metadata][:udf5] = application_id || 'ActiveMerchant'
      end

      def add_authorization_type(post, options)
        post[:authorization_type] = options[:authorization_type] if options[:authorization_type]
      end

      def add_metadata(post, options, payment_method = nil)
        post[:metadata] = {} unless post[:metadata]
        post[:metadata].merge!(options[:metadata]) if options[:metadata]
        post[:metadata][:udf1] = 'mada' if payment_method.try(:brand) == 'mada'
      end

      def add_payment_method(post, payment_method, options)
        post[:source] = {}
        if payment_method.is_a?(NetworkTokenizationCreditCard)
          token_type = token_type_from(payment_method)
          cryptogram = payment_method.payment_cryptogram
          eci = payment_method.eci || options[:eci]
          eci ||= '05' if token_type == 'vts'

          post[:source][:type] = 'network_token'
          post[:source][:token] = payment_method.number
          post[:source][:token_type] = token_type
          post[:source][:cryptogram] = cryptogram if cryptogram
          post[:source][:eci] = eci if eci
        elsif payment_method.is_a?(CreditCard)
          post[:source][:type] = 'card'
          post[:source][:name] = payment_method.name
          post[:source][:number] = payment_method.number
          post[:source][:cvv] = payment_method.verification_value
          post[:source][:stored] = 'true' if options[:card_on_file] == true
        end
        unless payment_method.is_a?(String)
          post[:source][:expiry_year] = format(payment_method.year, :four_digits)
          post[:source][:expiry_month] = format(payment_method.month, :two_digits)
        end
      end

      def add_customer_data(post, options)
        post[:customer] = {}
        post[:customer][:email] = options[:email] || nil
        post[:payment_ip] = options[:ip] if options[:ip]
        address = options[:billing_address]
        if address && post[:source]
          post[:source][:billing_address] = {}
          post[:source][:billing_address][:address_line1] = address[:address1] unless address[:address1].blank?
          post[:source][:billing_address][:address_line2] = address[:address2] unless address[:address2].blank?
          post[:source][:billing_address][:city] = address[:city] unless address[:city].blank?
          post[:source][:billing_address][:state] = address[:state] unless address[:state].blank?
          post[:source][:billing_address][:country] = address[:country] unless address[:country].blank?
          post[:source][:billing_address][:zip] = address[:zip] unless address[:zip].blank?
        end
      end

      def add_transaction_data(post, options = {})
        post[:payment_type] = 'Regular' if options[:transaction_indicator] == 1
        post[:payment_type] = 'Recurring' if options[:transaction_indicator] == 2
        post[:payment_type] = 'MOTO' if options[:transaction_indicator] == 3 || options.dig(:metadata, :manual_entry)
        post[:previous_payment_id] = options[:previous_charge_id] if options[:previous_charge_id]
      end

      def add_stored_credential_options(post, options = {})
        return unless options[:stored_credential]

        case options[:stored_credential][:initial_transaction]
        when true
          post[:merchant_initiated] = false
        when false
          post[:'source.stored'] = true
          post[:previous_payment_id] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
          post[:merchant_initiated] = true
        end

        case options[:stored_credential][:reason_type]
        when 'recurring', 'installment'
          post[:payment_type] = 'Recurring'
        when 'unscheduled'
          return
        end
      end

      def add_3ds(post, options)
        if options[:three_d_secure] || options[:execute_threed]
          post[:'3ds'] = {}
          post[:'3ds'][:enabled] = true
          post[:success_url] = options[:callback_url] if options[:callback_url]
          post[:failure_url] = options[:callback_url] if options[:callback_url]
          post[:'3ds'][:attempt_n3d] = options[:attempt_n3d] if options[:attempt_n3d]
          post[:'3ds'][:challenge_indicator] = options[:challenge_indicator] if options[:challenge_indicator]
          post[:'3ds'][:exemption] = options[:exemption] if options[:exemption]
        end

        if options[:three_d_secure]
          post[:'3ds'][:eci] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
          post[:'3ds'][:cryptogram] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          post[:'3ds'][:version] = options[:three_d_secure][:version] if options[:three_d_secure][:version]
          post[:'3ds'][:xid] = options[:three_d_secure][:ds_transaction_id] || options[:three_d_secure][:xid]
          post[:'3ds'][:status] = options[:three_d_secure][:authentication_response_status]
        end
      end

      def add_processing_channel(post, options)
        post[:processing_channel_id] = options[:processing_channel_id] if options[:processing_channel_id]
      end

      def add_marketplace_data(post, options)
        if options[:marketplace]
          post[:marketplace] = {}
          post[:marketplace][:sub_entity_id] = options[:marketplace][:sub_entity_id] if options[:marketplace][:sub_entity_id]
        end
      end

      def access_token_header
        {
          'Authorization' => "Basic #{Base64.encode64("#{@options[:client_id]}:#{@options[:client_secret]}").delete("\n")}",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def access_token_url
        test? ? TEST_ACCESS_TOKEN_URL : LIVE_ACCESS_TOKEN_URL
      end

      def setup_access_token
        request = 'grant_type=client_credentials'
        response = parse(ssl_post(access_token_url, request, access_token_header))
        response['access_token']
      end

      def commit(action, post, authorization = nil)
        begin
          raw_response = (action == :verify_payment ? ssl_get("#{base_url}/payments/#{post}", headers) : ssl_post(url(post, action, authorization), post.to_json, headers))
          response = parse(raw_response)
          response['id'] = response['_links']['payment']['href'].split('/')[-1] if action == :capture && response.key?('_links')
        rescue ResponseError => e
          raise unless e.response.code.to_s =~ /4\d\d/

          response = parse(e.response.body, error: e.response)
        end

        succeeded = success_from(response)

        response(action, succeeded, response)
      end

      def response(action, succeeded, response)
        successful_response = succeeded && action == :purchase || action == :authorize
        avs_result = successful_response ? avs_result(response) : nil
        cvv_result = successful_response ? cvv_result(response) : nil

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(succeeded, response),
          test: test?,
          avs_result: avs_result,
          cvv_result: cvv_result
        )
      end

      def headers
        auth_token = @access_token ? "Bearer #{@access_token}" : @options[:secret_key]
        {
          'Authorization' => auth_token,
          'Content-Type' => 'application/json;charset=UTF-8'
        }
      end

      def url(_post, action, authorization)
        if %i[authorize purchase].include?(action)
          "#{base_url}/payments"
        elsif action == :capture
          "#{base_url}/payments/#{authorization}/captures"
        elsif action == :refund
          "#{base_url}/payments/#{authorization}/refunds"
        elsif action == :void
          "#{base_url}/payments/#{authorization}/voids"
        elsif action == :incremental_authorize
          "#{base_url}/payments/#{authorization}/authorizations"
        else
          "#{base_url}/payments/#{authorization}/#{action}"
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def avs_result(response)
        response['source'] && response['source']['avs_check'] ? AVSResult.new(code: response['source']['avs_check']) : nil
      end

      def cvv_result(response)
        response['source'] && response['source']['cvv_check'] ? CVVResult.new(response['source']['cvv_check']) : nil
      end

      def parse(body, error: nil)
        JSON.parse(body)
      rescue JSON::ParserError
        response = {
          'error_type' => error&.code,
          'message' => 'Invalid JSON response received from Checkout.com Unified Payments Gateway. Please contact Checkout.com if you continue to receive this message.',
          'raw_response' => scrub(body)
        }
        response['error_codes'] = [error&.message] if error&.message
        response
      end

      def success_from(response)
        response['response_summary'] == 'Approved' || response['approved'] == true || !response.key?('response_summary') && response.key?('action_id')
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        elsif response['error_type']
          response['error_type'] + ': ' + response['error_codes'].first
        else
          response['response_summary'] || response['response_code'] || response['status'] || response['message'] || 'Unable to read error message'
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        '20014' => STANDARD_ERROR_CODE[:invalid_number],
        '20100' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '20054' => STANDARD_ERROR_CODE[:expired_card],
        '40104' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '40108' => STANDARD_ERROR_CODE[:incorrect_zip],
        '40111' => STANDARD_ERROR_CODE[:incorrect_address],
        '20005' => STANDARD_ERROR_CODE[:card_declined],
        '20088' => STANDARD_ERROR_CODE[:processing_error],
        '20001' => STANDARD_ERROR_CODE[:call_issuer],
        '30004' => STANDARD_ERROR_CODE[:pickup_card]
      }

      def authorization_from(raw)
        raw['id']
      end

      def error_code_from(succeeded, response)
        return if succeeded

        if response['error_type'] && response['error_codes']
          "#{response['error_type']}: #{response['error_codes'].join(', ')}"
        elsif response['error_type']
          response['error_type']
        else
          STANDARD_ERROR_CODE_MAPPING[response['response_code']]
        end
      end

      def token_type_from(payment_method)
        case payment_method.source
        when :network_token
          payment_method.brand == 'visa' ? 'vts' : 'mdes'
        when :google_pay, :android_pay
          'googlepay'
        when :apple_pay
          'applepay'
        end
      end
    end
  end
end
