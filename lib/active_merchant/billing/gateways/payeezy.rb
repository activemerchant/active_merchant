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

      def purchase(amount, payment_method, options = {})
        params = {transaction_type: 'purchase'}

        add_invoice(params, options)
        add_payment_method(params, payment_method, options)
        add_address(params, options)
        add_amount(params, amount, options)
        add_soft_descriptors(params, options)

        commit(params, options)
      end

      def authorize(amount, payment_method, options = {})
        params = {transaction_type: 'authorize'}

        add_invoice(params, options)
        add_payment_method(params, payment_method, options)
        add_address(params, options)
        add_amount(params, amount, options)
        add_soft_descriptors(params, options)

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

      def void(authorization, options = {})
        params = {transaction_type: 'void'}

        add_authorization_info(params, authorization)
        add_amount(params, amount_from_authorization(authorization), options)

        commit(params, options)
      end

      def verify(credit_card, options={})
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
          gsub(%r((Token: )(\w|-)+), '\1[FILTERED]').
          gsub(%r((\\?"card_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"cvv\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"account_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((\\?"routing_number\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(params, options)
        params[:merchant_ref] = options[:order_id]
      end

      def amount_from_authorization(authorization)
        authorization.split('|').last.to_i
      end

      def add_authorization_info(params, authorization)
        transaction_id, transaction_tag, method, _ = authorization.split('|')
        params[:transaction_id] = transaction_id
        params[:transaction_tag] = transaction_tag
        params[:method] = method
      end

      def add_payment_method(params, payment_method, options)
        if payment_method.is_a? Check
          add_echeck(params, payment_method, options)
        else
          add_creditcard(params, payment_method)
        end
      end

      def add_creditcard(params, creditcard)
        credit_card = {}

        credit_card[:type] = CREDIT_CARD_BRAND[creditcard.brand]
        credit_card[:cardholder_name] = creditcard.name
        credit_card[:card_number] = creditcard.number
        credit_card[:exp_date] = "#{format(creditcard.month, :two_digits)}#{format(creditcard.year, :two_digits)}"
        credit_card[:cvv] = creditcard.verification_value if creditcard.verification_value?

        params[:method] = 'credit_card'
        params[:credit_card] = credit_card
      end

      def add_echeck(params, echeck, options)
        tele_check = {}

        tele_check[:check_number] = echeck.number || "001"
        tele_check[:check_type] = "P"
        tele_check[:routing_number] = echeck.routing_number
        tele_check[:account_number] = echeck.account_number
        tele_check[:accountholder_name] = "#{echeck.first_name} #{echeck.last_name}"
        tele_check[:customer_id_type] = options[:customer_id_type] if options[:customer_id_type]
        tele_check[:customer_id_number] = options[:customer_id_number] if options[:customer_id_number]
        tele_check[:client_email] = options[:client_email] if options[:client_email]

        params[:method] = 'tele_check'
        params[:tele_check] = tele_check
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

      def commit(params, options)
        url = if options[:integration]
          integration_url
        elsif test?
          test_url
        else
          live_url
        end

        if transaction_id = params.delete(:transaction_id)
          url = "#{url}/#{transaction_id}"
        end

        begin
          body = params.to_json
          response = parse(ssl_post(url, body, headers(body)))
        rescue ResponseError => e
          response = response_error(e.response.body)
        rescue JSON::ParserError
          response = json_error(raw_response)
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

      def success_from(response)
        response['transaction_status'] == 'approved'
      end

      def authorization_from(params, response)
        [
          response['transaction_id'],
          response['transaction_tag'],
          params[:method],
          (response['amount'] && response['amount'].to_i)
        ].join('|')
      end

      def generate_hmac(nonce, current_timestamp, payload)
        message = [
          @options[:apikey],
          nonce.to_s,
          current_timestamp.to_s,
          @options[:token],
          payload
        ].join("")
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

      def handle_message(response, success)
        if success
          "#{response['gateway_message']} - #{response['bank_message']}"
        elsif %w(401 403).include?(response['code'])
          response['message']
        elsif response.key?('Error')
          response['Error']['messages'].first['description']
        elsif response.key?('error')
          response['error']
        elsif response.key?('fault')
          response['fault'].to_h['faultstring']
        else
          response['bank_message']
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
        {"error" => "Unable to parse response: #{raw_response.inspect}"}
      end
    end
  end
end
