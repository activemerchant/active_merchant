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
      self.supported_cardtypes = %i[visa master american_express diners_club maestro discover jcb mada bp_plus]
      self.currencies_without_fractions = %w(BIF DJF GNF ISK KMF XAF CLF XPF JPY PYG RWF KRW VUV VND XOF)
      self.currencies_with_three_decimal_places = %w(BHD LYD JOD KWD OMR TND)

      LIVE_ACCESS_TOKEN_URL = 'https://access.checkout.com/connect/token'
      TEST_ACCESS_TOKEN_URL = 'https://access.sandbox.checkout.com/connect/token'

      def initialize(options = {})
        @options = options
        @access_token = nil

        if options.has_key?(:secret_key)
          requires!(options, :secret_key)
        else
          requires!(options, :client_id, :client_secret)
          @access_token = setup_access_token
        end

        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        build_auth_or_purchase(post, amount, payment_method, options)

        commit(:purchase, post, options)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        post[:capture] = false
        build_auth_or_purchase(post, amount, payment_method, options)
        options[:incremental_authorization] ? commit(:incremental_authorize, post, options, options[:incremental_authorization]) : commit(:authorize, post, options)
      end

      def capture(amount, authorization, options = {})
        post = {}
        post[:capture_type] = options[:capture_type] || 'Final'
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit(:capture, post, options, authorization)
      end

      def credit(amount, payment, options = {})
        post = {}
        post[:instruction] = {}
        post[:instruction][:funds_transfer_type] = options[:funds_transfer_type] || 'FD'
        add_processing_channel(post, options)
        add_invoice(post, amount, options)
        add_payment_method(post, payment, options, :destination)
        add_source(post, options)

        commit(:credit, post, options)
      end

      def void(authorization, _options = {})
        post = {}
        add_metadata(post, options)

        commit(:void, post, options, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit(:refund, post, options, authorization)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
      end

      def verify_payment(authorization, option = {})
        commit(:verify_payment, nil, options, authorization, :get)
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
          gsub(/(source\\":\{.*\\"token\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("token\\":\\")\w+/, '\1[FILTERED]')
      end

      def store(payment_method, options = {})
        post = {}
        MultiResponse.run do |r|
          if payment_method.is_a?(NetworkTokenizationCreditCard)
            r.process { verify(payment_method, options) }
            break r unless r.success?

            r.params['source']['customer'] = r.params['customer']
            r.process { response(:store, true, r.params['source']) }
          else
            r.process { tokenize(payment_method, options) }
            break r unless r.success?

            token = r.params['token']
            add_payment_method(post, token, options)
            post.merge!(post.delete(:source))
            add_customer_data(post, options)
            r.process { commit(:store, post, options) }
          end
        end
      end

      def unstore(id, options = {})
        commit(:unstore, nil, options, id, :delete)
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

      def add_payment_method(post, payment_method, options, key = :source)
        post[key] = {}
        case payment_method
        when NetworkTokenizationCreditCard
          token_type = token_type_from(payment_method)
          cryptogram = payment_method.payment_cryptogram
          eci = payment_method.eci || options[:eci]
          eci ||= '05' if token_type == 'vts'

          post[key][:type] = 'network_token'
          post[key][:token] = payment_method.number
          post[key][:token_type] = token_type
          post[key][:cryptogram] = cryptogram if cryptogram
          post[key][:eci] = eci if eci
        when CreditCard
          post[key][:type] = 'card'
          post[key][:name] = payment_method.name
          post[key][:number] = payment_method.number
          post[key][:cvv] = payment_method.verification_value
          post[key][:stored] = 'true' if options[:card_on_file] == true
          if options[:account_holder_type]
            post[key][:account_holder] = {}
            post[key][:account_holder][:type] = options[:account_holder_type]
            post[key][:account_holder][:first_name] = payment_method.first_name if payment_method.first_name
            post[key][:account_holder][:last_name] = payment_method.last_name if payment_method.last_name
          else
            post[key][:first_name] = payment_method.first_name if payment_method.first_name
            post[key][:last_name] = payment_method.last_name if payment_method.last_name
          end
        end
        if payment_method.is_a?(String)
          if /tok/.match?(payment_method)
            post[:type] = 'token'
            post[:token] = payment_method
          elsif /src/.match?(payment_method)
            post[key][:type] = 'id'
            post[key][:id] = payment_method
          else
            add_source(post, options)
          end
        elsif payment_method.try(:year)
          post[key][:expiry_year] = format(payment_method.year, :four_digits)
          post[key][:expiry_month] = format(payment_method.month, :two_digits)
        end
      end

      def add_source(post, options)
        post[:source] = {}
        post[:source][:type] = options[:source_type] if options[:source_type]
        post[:source][:id] = options[:source_id] if options[:source_id]
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

      def merchant_initiated_override(post, options)
        post[:merchant_initiated] = true
        post[:source][:stored] = true
        post[:previous_payment_id] = options[:merchant_initiated_transaction_id]
      end

      def add_stored_credentials_using_normalized_fields(post, options)
        if options[:stored_credential][:initial_transaction] == true
          post[:merchant_initiated] = false
        else
          post[:source][:stored] = true
          post[:previous_payment_id] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
          post[:merchant_initiated] = true
        end
      end

      def add_stored_credential_options(post, options = {})
        return unless options[:stored_credential]

        post[:payment_type] = 'Recurring' if %w(recurring installment).include? options[:stored_credential][:reason_type]

        if options[:merchant_initiated_transaction_id]
          merchant_initiated_override(post, options)
        else
          add_stored_credentials_using_normalized_fields(post, options)
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

      def commit(action, post, options, authorization = nil, method = :post)
        begin
          raw_response = ssl_request(method, url(action, authorization), post.nil? || post.empty? ? nil : post.to_json, headers(action, options))
          response = parse(raw_response)
          response['id'] = response['_links']['payment']['href'].split('/')[-1] if action == :capture && response.key?('_links')
          source_id = authorization if action == :unstore
        rescue ResponseError => e
          raise unless e.response.code.to_s =~ /4\d\d/

          response = parse(e.response.body, error: e.response)
        end

        succeeded = success_from(action, response)

        response(action, succeeded, response, source_id)
      end

      def response(action, succeeded, response, source_id = nil)
        successful_response = succeeded && action == :purchase || action == :authorize
        avs_result = successful_response ? avs_result(response) : nil
        cvv_result = successful_response ? cvv_result(response) : nil
        authorization = authorization_from(response) unless action == :unstore
        body = action == :unstore ? { response_code: response.to_s } : response
        Response.new(
          succeeded,
          message_from(succeeded, response),
          body,
          authorization: authorization,
          error_code: error_code_from(succeeded, body),
          test: test?,
          avs_result: avs_result,
          cvv_result: cvv_result
        )
      end

      def headers(action, options)
        auth_token = @access_token ? "Bearer #{@access_token}" : @options[:secret_key]
        auth_token = @options[:public_key] if action == :tokens
        headers = {
          'Authorization' => auth_token,
          'Content-Type' => 'application/json;charset=UTF-8'
        }
        headers['Cko-Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def tokenize(payment_method, options = {})
        post = {}
        add_authorization_type(post, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        commit(:tokens, post[:source], options)
      end

      def url(action, authorization)
        case action
        when :authorize, :purchase, :credit
          "#{base_url}/payments"
        when :unstore, :store
          "#{base_url}/instruments/#{authorization}"
        when :capture
          "#{base_url}/payments/#{authorization}/captures"
        when :refund
          "#{base_url}/payments/#{authorization}/refunds"
        when :void
          "#{base_url}/payments/#{authorization}/voids"
        when :incremental_authorize
          "#{base_url}/payments/#{authorization}/authorizations"
        when :tokens
          "#{base_url}/tokens"
        when :verify_payment
          "#{base_url}/payments/#{authorization}"
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

      def success_from(action, response)
        return response['status'] == 'Pending' if action == :credit
        return true if action == :unstore && response == 204

        store_response = response['token'] || response['id']
        if store_response
          return true if (action == :tokens && store_response.match(/tok/)) || (action == :store && store_response.match(/src_/))
        end
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

      def handle_response(response)
        case response.code.to_i
        # to get the response code after unstore(delete instrument), because the body is nil
        when 200...300
          response.body || response.code
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
