module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ReachGateway < Gateway
      # TODO: Things to check
      # * The list of three digit fractions but only accept 2
      # * Not sure the list of countries and currencies

      self.test_url = 'https://checkout.rch.how/'
      self.live_url = 'https://checkout.rch.io/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa diners_club american_express jcb master discover maestro]

      self.homepage_url = 'https://www.withreach.com/'
      self.display_name = 'Reach'
      self.currencies_without_fractions = %w(BIF BYR CLF CLP CVE DJF GNF ISK JPY KMF KRW PYG RWF UGX UYI VND VUV XAF XOF XPF IDR MGA MRO)

      API_VERSION = 'v2.22'.freeze
      STANDARD_ERROR_CODE_MAPPING = {}
      PAYMENT_METHOD_MAP = {
        american_express: 'AMEX',
        cabal: 'CABAL',
        check: 'ACH',
        dankort: 'DANKORT',
        diners_club: 'DINERS',
        discover: 'DISC',
        elo: 'ELO',
        jcb: 'JCB',
        maestro: 'MAESTRO',
        master: 'MC',
        naranja: 'NARANJA',
        union_pay: 'UNIONPAY',
        visa: 'VISA'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :secret)
        super
      end

      def authorize(money, payment, options = {})
        request = build_checkout_request(money, payment, options)
        add_custom_fields_data(request, options)
        add_customer_data(request, options, payment)
        add_stored_credentials(request, options)
        post = { request: request, card: add_payment(payment, options) }
        if options[:stored_credential]
          MultiResponse.run(:use_first_response) do |r|
            r.process { commit('checkout', post) }
            r.process do
              r2 = get_network_payment_reference(r.responses[0])
              r.params[:network_transaction_id] = r2.message
              r2
            end
          end
        else
          commit('checkout', post)
        end
      end

      def purchase(money, payment, options = {})
        options[:capture] = true
        authorize(money, payment, options)
      end

      def capture(money, authorization, options = {})
        post = { request: { MerchantId: @options[:merchant_id], OrderId: authorization } }
        commit('capture', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(((MerchantId)[% \w]+[%]\d{2})[\w -]+), '\1[FILTERED]').
          gsub(%r((signature=)[\w%]+), '\1[FILTERED]\2').
          gsub(%r((Number%22%3A%22)[\d]+), '\1[FILTERED]\2').
          gsub(%r((VerificationCode%22%3A)[\d]+), '\1[FILTERED]\2')
      end

      def refund(amount, authorization, options = {})
        post = {
          request: {
            MerchantId: @options[:merchant_id],
            OrderId: authorization,
            ReferenceId: options[:order_id] || options[:reference_id],
            Amount: amount
          }
        }
        commit('refund', post)
      end

      def void(authorization, options = {})
        post = {
          request: {
            MerchantId: @options[:merchant_id],
            OrderId: authorization
          }
        }

        commit('cancel', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def build_checkout_request(amount, payment, options)
        raise ArgumentError.new("Payment method #{payment.brand} is not supported, check https://docs.withreach.com/docs/credit-cards#technical-considerations") if PAYMENT_METHOD_MAP[payment.brand.to_sym].blank?

        {
          MerchantId: @options[:merchant_id],
          ReferenceId: options[:order_id],
          ConsumerCurrency: options[:currency] || currency(options[:amount]),
          Capture: options[:capture] || false,
          PaymentMethod: PAYMENT_METHOD_MAP[payment.brand.to_sym],
          Items: [
            Sku: options[:item_sku] || SecureRandom.alphanumeric,
            ConsumerPrice: amount,
            Quantity: (options[:item_quantity] || 1)
          ]
        }
      end

      def add_payment(payment, options)
        ntid = options.dig(:stored_credential, :network_transaction_id)
        cvv_or_previos_reference = (ntid ? { PreviousNetworkPaymentReference: ntid } : { VerificationCode: payment.verification_value })
        {
          Name: payment.name,
          Number: payment.number,
          Expiry: { Month: payment.month, Year: payment.year }
        }.merge!(cvv_or_previos_reference)
      end

      def add_customer_data(request, options, payment)
        address = options[:billing_address] || options[:address]

        return if address.blank?

        request[:Consumer] = {
          Name: payment.respond_to?(:name) ? payment.name : address[:name],
          Email: options[:email],
          Address: address[:address1],
          City: address[:city],
          Country: address[:country]
        }.compact
      end

      def add_stored_credentials(request, options)
        request[:PaymentModel] = payment_model(options)
        raise ArgumentError, 'Unexpected combination of stored credential fields' if request[:PaymentModel].nil?

        request[:DeviceFingerprint] = options[:device_fingerprint] if options[:device_fingerprint] && request[:PaymentModel].match?(/CIT-/)
      end

      def payment_model(options)
        stored_credential = options[:stored_credential]
        return options[:payment_model] if options[:payment_model]
        return 'CIT-One-Time' unless stored_credential

        payment_model_options = {
          initial_transaction: {
            'cardholder' => {
              'installment' => 'CIT-Setup-Scheduled',
              'unschedule' => 'CIT-Setup-Unscheduled-MIT',
              'recurring' => 'CIT-Setup-Unscheduled'
            }
          },
          no_initial_transaction: {
            'cardholder' => {
              'unschedule' => 'CIT-Subsequent-Unscheduled'
            },
            'merchant' => {
              'recurring' => 'MIT-Subsequent-Scheduled',
              'unschedule' => 'MIT-Subsequent-Unscheduled'
            }
          }
        }
        initial = (stored_credential[:initial_transaction] ? :initial_transaction : :no_initial_transaction)
        payment_model_options[initial].dig(stored_credential[:initiator], stored_credential[:reason_type])
      end

      def add_custom_fields_data(request, options)
        add_shipping_data(request, options) if options[:taxes].present?
        request[:RateOfferId] = options[:rate_offer_id] if options[:rate_offer_id].present?
        request[:Items] = options[:items] if options[:items].present?
      end

      def add_shipping_data(request, options)
        request[:Shipping] = {
          ConsumerPrice: options[:price],
          ConsumerTaxes: options[:taxes],
          ConsumerDuty: options[:duty]
        }
        request[:Consignee] = {
          Name: options[:consignee_name],
          Address: options[:consignee_address],
          City: options[:consignee_city],
          Country: options[:consignee_country]
        }
      end

      def sign_body(body)
        Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', @options[:secret].encode('utf-8'), body.encode('utf-8')))
      end

      def parse(body)
        hash_response = URI.decode_www_form(body).to_h
        hash_response['response'] = JSON.parse(hash_response['response'])

        hash_response
      end

      def format_and_sign(post)
        post[:request] = post[:request].to_json
        post[:card] = post[:card].to_json if post[:card].present?
        post[:signature] = sign_body(post[:request])
        post
      end

      def get_network_payment_reference(response)
        parameters = { request: { MerchantId: @options[:merchant_id], OrderId: response.params['response']['OrderId'] } }
        body = post_data format_and_sign(parameters)

        raw_response = ssl_request :post, url('query'), body, {}
        response = parse(raw_response)
        message = response.dig('response', 'Payment', 'NetworkPaymentReference')
        Response.new(true, message, {})
      end

      def commit(action, parameters)
        body = post_data format_and_sign(parameters)
        raw_response = ssl_post url(action), body
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response) || '',
          response,
          authorization: authorization_from(response['response']),
          # avs_result: AVSResult.new(code: response['some_avs_response_key']),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ActiveMerchant::ResponseError => e
        Response.new(false, (e.response.body.present? ? e.response.body : e.response.msg), {}, test: test?)
      end

      def success_from(response)
        response.dig('response', 'Error').blank?
      end

      def message_from(response)
        success_from(response) ? '' : response.dig('response', 'Error', 'ReasonCode')
      end

      def authorization_from(response)
        response['OrderId']
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def error_code_from(response)
        response['response']['Error']['Code'] unless success_from(response)
      end

      def url(action)
        "#{test? ? test_url : live_url}#{API_VERSION}/#{action}"
      end
    end
  end
end
