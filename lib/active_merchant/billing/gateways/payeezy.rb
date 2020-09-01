module ActiveMerchant
  module Billing
    class PayeezyGateway < Gateway
      class_attribute :integration_url

      self.test_url = 'https://api-cert.payeezy.com/v1'
      self.integration_url = 'https://api-cat.payeezy.com/v1'
      self.live_url = 'https://api.payeezy.com/v1'

      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_countries = %w(US CA)

      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club]

      self.homepage_url = 'https://developer.payeezy.com/'
      self.display_name = 'Payeezy'

      CREDIT_CARD_BRAND = {
        'visa' => 'Visa',
        'master' => 'Mastercard',
        'american_express' => 'American Express',
        'discover' => 'Discover',
        'jcb' => 'JCB',
        'diners_club' => 'Diners Club'
      }

      def initialize(options = {})
        requires!(options, :apikey, :apisecret, :token)
        super
      end

      def purchase(amount, payment_method, options = {})
        params = payment_method.is_a?(String) ? { transaction_type: 'recurring' } : { transaction_type: 'purchase' }

        add_invoice(params, options)
        add_reversal_id(params, options)
        add_payment_method(params, payment_method, options)
        add_address(params, options)
        add_amount(params, amount, options)
        add_soft_descriptors(params, options)
        add_stored_credentials(params, options)

        commit(params, options)
      end

      def authorize(amount, payment_method, options = {})
        params = {transaction_type: 'authorize'}

        add_invoice(params, options)
        add_reversal_id(params, options)
        add_payment_method(params, payment_method, options)
        add_address(params, options)
        add_amount(params, amount, options)
        add_soft_descriptors(params, options)
        add_stored_credentials(params, options)

        commit(params, options)
      end

      def capture(amount, authorization, options = {})
        params = {transaction_type: 'capture'}

        add_authorization_info(params, authorization)
        add_amount(params, amount, options)
        add_soft_descriptors(params, options)

        commit(params, options)
      end

      def refund(amount, authorization, options = {})
        params = {transaction_type: 'refund'}

        add_authorization_info(params, authorization)
        add_amount(params, (amount || amount_from_authorization(authorization)), options)

        commit(params, options)
      end

      def store(payment_method, options = {})
        params = {transaction_type: 'store'}

        add_creditcard_for_tokenization(params, payment_method, options)

        commit(params, options)
      end

      def void(authorization, options = {})
        params = {transaction_type: 'void'}

        add_authorization_info(params, authorization, options)
        add_amount(params, amount_from_authorization(authorization), options)

        commit(params, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Token: )(\w|-)+), '\1[FILTERED]').
          gsub(%r((Apikey: )(\w|-)+), '\1[FILTERED]').
          gsub(%r((\\?"card_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"cvv\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"account_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"routing_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?card_number=)\d+(&?)), '\1[FILTERED]').
          gsub(%r((\\?cvv=)\d+(&?)), '\1[FILTERED]').
          gsub(%r((\\?apikey=)\w+(&?)), '\1[FILTERED]').
          gsub(%r{(\\?"credit_card\.card_number\\?":)(\\?"[^"]+\\?")}, '\1[FILTERED]').
          gsub(%r{(\\?"credit_card\.cvv\\?":)(\\?"[^"]+\\?")}, '\1[FILTERED]').
          gsub(%r{(\\?"apikey\\?":)(\\?"[^"]+\\?")}, '\1[FILTERED]')
      end

      private

      def add_invoice(params, options)
        params[:merchant_ref] = options[:order_id]
      end

      def add_reversal_id(params, options)
        params[:reversal_id] = options[:reversal_id] if options[:reversal_id]
      end

      def amount_from_authorization(authorization)
        authorization.split('|').last.to_i
      end

      def add_authorization_info(params, authorization, options = {})
        transaction_id, transaction_tag, method, = authorization.split('|')
        params[:method] = method == 'token' ? 'credit_card' : method

        if options[:reversal_id]
          params[:reversal_id] = options[:reversal_id]
        else
          params[:transaction_id] = transaction_id
          params[:transaction_tag] = transaction_tag
        end
      end

      def add_creditcard_for_tokenization(params, payment_method, options)
        params[:apikey] = @options[:apikey]
        params[:ta_token] = options[:ta_token]
        params[:type] = 'FDToken'
        params[:credit_card] = add_card_data(payment_method)
        params[:auth] = 'false'
      end

      def store_action?(params)
        params[:transaction_type] == 'store'
      end

      def add_payment_method(params, payment_method, options)
        if payment_method.is_a? Check
          add_echeck(params, payment_method, options)
        elsif payment_method.is_a? String
          add_token(params, payment_method, options)
        else
          add_creditcard(params, payment_method)
        end
      end

      def add_echeck(params, echeck, options)
        tele_check = {}

        tele_check[:check_number] = echeck.number || '001'
        tele_check[:check_type] = 'P'
        tele_check[:routing_number] = echeck.routing_number
        tele_check[:account_number] = echeck.account_number
        tele_check[:accountholder_name] = "#{echeck.first_name} #{echeck.last_name}"
        tele_check[:customer_id_type] = options[:customer_id_type] if options[:customer_id_type]
        tele_check[:customer_id_number] = options[:customer_id_number] if options[:customer_id_number]
        tele_check[:client_email] = options[:client_email] if options[:client_email]

        params[:method] = 'tele_check'
        params[:tele_check] = tele_check
      end

      def add_token(params, payment_method, options)
        token = {}
        token[:token_type] = 'FDToken'

        type, cardholder_name, exp_date, card_number = payment_method.split('|')

        token[:token_data] = {}
        token[:token_data][:type] = type
        token[:token_data][:cardholder_name] = cardholder_name
        token[:token_data][:value] = card_number
        token[:token_data][:exp_date] = exp_date
        token[:token_data][:cvv] = options[:cvv] if options[:cvv]

        params[:method] = 'token'
        params[:token] = token
      end

      def add_creditcard(params, creditcard)
        credit_card = add_card_data(creditcard)

        params[:method] = 'credit_card'
        params[:credit_card] = credit_card
      end

      def add_card_data(payment_method)
        card = {}
        card[:type] = CREDIT_CARD_BRAND[payment_method.brand]
        card[:cardholder_name] = payment_method.name
        card[:card_number] = payment_method.number
        card[:exp_date] = format_exp_date(payment_method.month, payment_method.year)
        card[:cvv] = payment_method.verification_value if payment_method.verification_value?
        card
      end

      def format_exp_date(month, year)
        "#{format(month, :two_digits)}#{format(year, :two_digits)}"
      end

      def add_address(params, options)
        address = options[:billing_address]
        return unless address

        billing_address = {}
        billing_address[:street] = address[:address1] if address[:address1]
        billing_address[:city] = address[:city] if address[:city]
        billing_address[:state_province] = address[:state] if address[:state]
        billing_address[:zip_postal_code] = address[:zip] if address[:zip]
        billing_address[:country] = address[:country] if address[:country]

        params[:billing_address] = billing_address
      end

      def add_amount(params, money, options)
        params[:currency_code] = (options[:currency] || default_currency).upcase
        params[:amount] = amount(money)
      end

      def add_soft_descriptors(params, options)
        params[:soft_descriptors] = options[:soft_descriptors] if options[:soft_descriptors]
      end

      def add_stored_credentials(params, options)
        if options[:sequence]
          params[:stored_credentials] = {}
          params[:stored_credentials][:cardbrand_original_transaction_id] = options[:cardbrand_original_transaction_id] if options[:cardbrand_original_transaction_id]
          params[:stored_credentials][:sequence] = options[:sequence]
          params[:stored_credentials][:initiator] = options[:initiator] if options[:initiator]
          params[:stored_credentials][:is_scheduled] = options[:is_scheduled]
          params[:stored_credentials][:auth_type_override] = options[:auth_type_override] if options[:auth_type_override]
        end
      end

      def commit(params, options)
        url = base_url(options) + endpoint(params)

        if transaction_id = params.delete(:transaction_id)
          url = "#{url}/#{transaction_id}"
        end

        begin
          response = api_request(url, params)
        rescue ResponseError => e
          response = response_error(e.response.body)
        rescue JSON::ParserError
          response = json_error(e.response.body)
        end

        Response.new(
          success_from(response),
          handle_message(response, success_from(response)),
          response,
          test: test?,
          authorization: authorization_from(params, response),
          avs_result: {code: response['avs']},
          cvv_result: response['cvv2'],
          error_code: error_code(response, success_from(response))
        )
      end

      def base_url(options)
        if options[:integration]
          integration_url
        elsif test?
          test_url
        else
          live_url
        end
      end

      def endpoint(params)
        store_action?(params) ? '/transactions/tokens' : '/transactions'
      end

      def api_request(url, params)
        body = params.to_json
        parse(ssl_post(url, body, headers(body)))
      end

      def post_data(params)
        return nil unless params

        params.reject { |k, v| v.blank? }.collect { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def generate_hmac(nonce, current_timestamp, payload)
        message = [
          @options[:apikey],
          nonce.to_s,
          current_timestamp.to_s,
          @options[:token],
          payload
        ].join('')
        hash = Base64.strict_encode64(OpenSSL::HMAC.hexdigest('sha256', @options[:apisecret], message))
        hash
      end

      def headers(payload)
        nonce = (SecureRandom.random_number * 10_000_000_000)
        current_timestamp = (Time.now.to_f * 1000).to_i
        {
          'Content-Type' => 'application/json',
          'apikey' => options[:apikey],
          'token' => options[:token],
          'nonce' => nonce.to_s,
          'timestamp' => current_timestamp.to_s,
          'Authorization' => generate_hmac(nonce, current_timestamp, payload)
        }
      end

      def error_code(response, success)
        return if success

        response['Error'].to_h['messages'].to_a.map { |e| e['code'] }.join(', ')
      end

      def success_from(response)
        if response['transaction_status']
          response['transaction_status'] == 'approved'
        elsif response['results']
          response['results']['status'] == 'success'
        elsif response['status']
          response['status'] == 'success'
        else
          false
        end
      end

      def handle_message(response, success)
        if success && response['status'].present?
          'Token successfully created.'
        elsif success
          "#{response['gateway_message']} - #{response['bank_message']}"
        elsif %w(401 403).include?(response['code'])
          response['message']
        elsif response.key?('Error')
          response['Error']['messages'].first['description']
        elsif response.key?('results')
          response['results']['Error']['messages'].first['description']
        elsif response.key?('error')
          response['error']
        elsif response.key?('fault')
          response['fault'].to_h['faultstring']
        else
          response['bank_message'] || response['gateway_message'] || 'Failure to successfully create token.'
        end
      end

      def authorization_from(params, response)
        if store_action?(params)
          if success_from(response)
            [
              response['token']['type'],
              response['token']['cardholder_name'],
              response['token']['exp_date'],
              response['token']['value']
            ].join('|')
          else
            nil
          end
        else
          [
            response['transaction_id'],
            response['transaction_tag'],
            params[:method],
            response['amount']&.to_i
          ].join('|')
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        {'error' => "Unable to parse response: #{raw_response.inspect}"}
      end
    end
  end
end
