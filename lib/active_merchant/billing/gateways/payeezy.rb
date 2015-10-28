module ActiveMerchant
  module Billing
    class PayeezyGateway < Gateway
      class_attribute :integration_url

      self.test_url = 'https://api-cert.payeezy.com/v1/transactions'
      self.integration_url = 'https://api-cat.payeezy.com/v1/transactions'
      self.live_url = 'https://api.payeezy.com/v1/transactions'

      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_countries = %w(US CA)

      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

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

      def purchase(money, creditcard, options = {})
        commit(:purchase, purchase_or_auth_request(money, creditcard, options))
      end

      def authorize(money, creditcard, options = {})
        commit(:authorize, purchase_or_auth_request(money, creditcard, options))
      end

      def capture(money, authorization, options = {})
        commit(:capture, capture_or_credit_request(money, authorization, options))
      end

      def refund(money, authorization, options = {})
        commit(:refund, capture_or_credit_request(money, authorization, options))
      end

      def void(authorization, options = {})
        commit(:void, capture_or_credit_request(amount_from_authorization(authorization), authorization, options))
      end

      private

      def init_options
        init_options = {}
        init_options[:url] = if options[:integration]
                               integration_url
                             else
                               "#{test? ? test_url : live_url}"
                             end

        init_options[:apikey] = options[:apikey]
        init_options[:apisecret] = options[:apisecret]
        init_options[:token] = options[:token]

        init_options
      end

      def capture_or_credit_request(money, authorization, options)
        params = {
          method: options[:method],
          merchant_ref: options[:merchant_ref]
        }

        add_authorization_info(params, authorization)
        add_amount(params, money, options)

        params
      end

      def purchase_or_auth_request(money, creditcard, options)
        params = {
          method: options[:method],
          merchant_ref: options[:merchant_ref],
          credit_card: add_creditcard(creditcard)
        }

        params[:billing_address] = add_address(options)
        add_amount(params, money, options)

        params
      end

      def amount_from_authorization(authorization)
        _, _, amount = authorization.split('|', 3)
        amount.to_i
      end

      def tokenize_authorization_info(response)
        if response['transaction_id'] && response['transaction_tag']
          [
            response['transaction_id'],
            response['transaction_tag'],
            (response['amount'].to_f).to_i
          ].join('|')
        else
          ''
        end
      end

      def add_authorization_info(post, authorization)
        transaction_id, transaction_tag, _ = authorization.split('|')
        post[:transaction_id] = transaction_id
        post[:transaction_tag] = transaction_tag
      end

      def add_creditcard(creditcard)
        return unless creditcard.respond_to?(:number)
        credit_card = {}

        credit_card[:type] = CREDIT_CARD_BRAND[creditcard.brand]
        credit_card[:cardholder_name] = creditcard.name
        credit_card[:card_number] = creditcard.number
        credit_card[:exp_date] = "#{format(creditcard.month, :two_digits)}#{format(creditcard.year, :two_digits)}"
        credit_card[:cvv] = creditcard.verification_value if creditcard.verification_value?

        credit_card
      end

      def add_address(options)
        address = options[:billing_address] || options[:address]
        return unless address

        billing_address = {}
        billing_address[:street] = address[:address1] if address[:address1]
        billing_address[:city] = address[:city] if address[:city]
        billing_address[:state_province] = address[:state] if address[:state]
        billing_address[:zip_postal_code] = address[:zip] if address[:zip]
        billing_address[:country] = address[:country] if address[:country]

        billing_address
      end

      def add_amount(request, money, options)
        request[:currency_code] = (options[:currency] || currency(money)).upcase
        request[:amount] = amount(money)
      end

      def commit(action, payload)
        request = payload.dup
        url = init_options[:url]

        if action == :capture || action == :void || action == :refund || action == :split
          url = url + '/' + request[:transaction_id]
          request.delete(:transaction_id)
        end
        request[:transaction_type] = action

        success = false
        begin
          raw_response = ssl_post url, post_data(request), headers(post_data(request))
          response = parse(raw_response)
          success = !response.key?('Error') && response['transaction_status'] == 'approved'
        rescue ResponseError => e
          response = response_error(e.response.body)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        Response.new(
          success,
          handle_message(response, success),
          response,
          response_options(response, success)
        )
      end

      def response_options(response, success)
        {
          test: test?,
          authorization: tokenize_authorization_info(response),
          avs_result: { code: response['avs'] },
          cvv_result: response['cvv2'],
          error_code: error_code(response, success)
        }
      end

      def generate_hmac(nonce, current_timestamp, payload)
        message = options[:apikey] + nonce.to_s + current_timestamp.to_s + options[:token] + payload
        hash = Base64.strict_encode64(bin_to_hex(OpenSSL::HMAC.digest('sha256', options[:apisecret], message)))
        hash
      end

      def bin_to_hex(s)
        s.unpack('H*').first
      end

      def headers(payload)
        nonce = SecureRandom.random_number * 10_000_000_000
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

      def handle_message(response, success)
        if success
          "#{response['gateway_message']} - #{response['bank_message']}"
        elsif %w(401 403).include? response['code']
          response['message']
        elsif response.key?('Error')
          response['Error'].to_h['messages'].map { |m| m['description'] }.join('. ')
        elsif response.key?('error')
          response['error']
        elsif response.key?('fault')
          response['fault'].to_h['faultstring']
        else
          response['bank_message']
        end
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def parse(body)
        JSON.parse(body)
      end

      def post_data(params)
        params.to_json
      end

      def json_error(raw_response)
        {
          'Error' => {
            'messages' => raw_response
          }
        }
      end
    end
  end
end
