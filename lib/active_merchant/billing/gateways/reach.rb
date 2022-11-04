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

        post = { request: request, card: add_payment(payment) }
        commit('checkout', post)
      end

      def purchase(money, payment, options = {})
        options[:capture] = true
        authorize(money, payment, options)
      end

      def capture(money, authorization, options = {})
        post = { request: { MerchantId: @options[:merchant_id], OrderId: authorization } }
        commit('capture', post)
      end

      private

      def build_checkout_request(amount, payment, options)
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
          ],
          ViaAgent: true # Indicates this is server to server API call
        }
      end

      def add_payment(payment)
        {
          Name: payment.name,
          Number: payment.number,
          Expiry: { Month: payment.month, Year: payment.year },
          VerificationCode: payment.verification_value
        }
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

      def add_custom_fields_data(request, options)
        if options[:fingerprint].present?
          request[:DeviceFingerprint] = options[:fingerprint]
          request[:ViaAgent] = false
        end
        add_shipping_data(request, options) if options[:consumer_taxes].present?
        request[:RateOfferId] = options[:rate_offer_id] if options[:rate_offer_id].present?
        request[:Items] = options[:items] if options[:items].present?
      end

      def add_shipping_data(request, options)
        request[:Shipping] = {
          ConsumerPrice: options[:consumer_price],
          ConsumerTaxes: options[:consumer_taxes],
          ConsumerDuty: options[:consumer_duty]
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
        hash_response = URI.decode_www_form(body).to_h.transform_keys!(&:to_sym)
        hash_response[:response] = JSON.parse(hash_response[:response], symbolize_names: true)

        hash_response
      end

      def format_and_sign(post)
        post[:request] = post[:request].to_json
        post[:card] = post[:card].to_json if post[:card].present?
        post[:signature] = sign_body(post[:request])
        post
      end

      def commit(action, parameters)
        body = post_data format_and_sign(parameters)
        raw_response = ssl_post url(action), body
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response) || '',
          response,
          authorization: authorization_from(response[:response]),
          # avs_result: AVSResult.new(code: response['some_avs_response_key']),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ActiveMerchant::ResponseError => e
        Response.new(false, (e.response.body.present? ? e.response.body : e.response.msg), {}, test: test?)
      end

      def success_from(response)
        response.dig(:response, :Error).blank?
      end

      def message_from(response)
        success_from(response) ? '' : response.dig(:response, :Error, :ReasonCode)
      end

      def authorization_from(response)
        response[:OrderId]
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def error_code_from(response)
        response[:response][:Error][:Code] unless success_from(response)
      end

      def url(action)
        "#{test? ? test_url : live_url}#{API_VERSION}/#{action}"
      end
    end
  end
end
