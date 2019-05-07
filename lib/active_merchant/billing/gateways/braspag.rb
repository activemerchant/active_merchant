module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraspagGateway < Gateway
      self.test_url = 'https://apisandbox.braspag.com.br'
      self.live_url = 'https://api.braspag.com.br'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :elo]
      self.money_format = :cents

      self.homepage_url = 'https://braspag.github.io/'
      self.display_name = 'Braspag'

      STANDARD_ERROR_CODE_MAPPING = {}

      STATUS_AUTHORIZED = 1
      STATUS_CAPTURED = 2
      STATUS_VOIDED = 10
      STATUS_REFUNDED = 11

      CARD_BRAND = {
        'visa' => 'Visa',
        'master' => 'Master',
        'american_express' => 'Amex',
        'diners_club' => 'Diners',
        'elo' => 'Elo'
      }.freeze

      HTTP_METHOD = {
        'purchase' => :post,
        'authorize' => :post,
        'capture' => :put,
        'refund' => :put,
        'void' => :put,
        'store' => :post
      }.freeze

      def initialize(options={})
        requires!(options, :merchant_id, :merchant_key)
        @merchant_id, @merchant_key = options.values_at(:merchant_id, :merchant_key)
        super
      end

      def purchase(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        post[:payment][:capture] = true
        commit('purchase', '/v2/sales', post)
      end

      def authorize(money, payment, options={})
        commit('authorize', '/v2/sales', create_post_for_auth_or_purchase(money, payment, options))
      end

      def capture(money, authorization, options={})
        post = {}
        authorization = authorization.split('|').first
        commit('capture', "/v2/sales/#{authorization}/capture", post)
      end


      def refund(money, authorization, options={})
        post = {}
        authorization = authorization.split('|').first
        commit('void', "/v2/sales/#{authorization}/void?amount=#{amount(money)}", post)
      end

      def void(authorization, options={})
        post = {}
        authorization = authorization.split('|').first
        commit('void', "/v2/sales/#{authorization}/void", post)
      end

      def store(credit_card, options={})
        post = create_post_for_card_tokenization(credit_card, options)
        MultiResponse.run(:use_first_response) do |r|
          r.process { commit('store', '/v2/sales', post) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
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
          gsub(%r((Merchantid: )[-\w]+), '\1[FILTERED]').
          gsub(%r((Merchantkey: )[-\w]+), '\1[FILTERED]').
          gsub(%r((cardNumber\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r((securityCode\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def init_post(options)
        post = { payment: {} }
        post[:merchantOrderId] = options[:order_id] if options[:order_id]
        post
      end

      def add_provider(post, options)
        post[:payment][:provider] = test? ? 'Simulado' : (options[:provider] || 'Cielo')
      end

      def add_invoice(post, money, options)
        post[:payment][:amount] = amount(money)
        post[:payment][:installments] = options[:installments] || 1
        post[:payment][:currency] = options[:currency] || currency(money)
        post[:payment][:softDescriptor] = options[:description] if options[:description]
      end

      def add_customer_data(post, credit_card, options)
        post[:customer] ||= {}
        post[:customer][:name] = options[:customer] if options[:customer]
        post[:customer][:email] = options[:email] if options[:email]
        post[:customer][:identity] = options[:document] if options[:document]
        post[:customer][:identityType] = 'CPF' if options[:document]
        post[:customer][:birthdate] = options[:birthdate] if options[:birthdate]
      end

      def add_address(post, options)
        return unless address = options[:billing_address] || options[:address]
        post[:customer] ||= {}
        post[:customer][:address] = {}
        post[:customer][:address][:street] = address[:address1] if address[:address1]
        post[:customer][:address][:number] = address[:number] if address[:number]
        post[:customer][:address][:complement] = address[:address2] if address[:address2]
        post[:customer][:address][:zipCode] = address[:zip] if address[:zip]
        post[:customer][:address][:city] = address[:city] if address[:city]
        post[:customer][:address][:state] = address[:state] if address[:state]
        post[:customer][:address][:country] = address[:country] if address[:country]
        post[:customer][:address][:district] = address[:district] if address[:district]
      end

      def add_antifraud_data(post, options)
        antifraud = {}
        antifraud.merge!(options[:antifraud]) if options[:antifraud]
        post[:payment][:fraudAnalysis] = antifraud unless antifraud.empty?
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          _, token, brand = payment.split('|')
          post[:payment][:type] = 'CreditCard'
          post[:payment][:creditCard] = { cardToken: token, brand: brand }
        else
          add_credit_card(post, payment)
        end
      end

      def add_credit_card(post, payment)
        month = format(payment.month, :two_digits)
        year  = format(payment.year, :four_digits)
        expiry_date = "#{month}/#{year}"

        post[:payment][:type] = 'CreditCard'
        post[:payment][:creditCard] = {}
        post[:payment][:creditCard][:cardNumber] = payment.number
        post[:payment][:creditCard][:holder] = payment.name
        post[:payment][:creditCard][:expirationDate] = expiry_date
        post[:payment][:creditCard][:securityCode] = payment.verification_value
        post[:payment][:creditCard][:brand] = CARD_BRAND[payment.brand]
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        post = init_post(options)
        add_provider(post, options)
        add_invoice(post, money, options)
        add_customer_data(post, payment, options)
        add_address(post, options)
        add_payment(post, payment)
        add_antifraud_data(post, options)
        post
      end

      def create_post_for_card_tokenization(credit_card, options)
        options.merge!(order_id: "store-#{generate_unique_id}")
        post = init_post(options)
        add_provider(post, options)
        add_invoice(post, 100, options)
        add_customer_data(post, credit_card, options)
        add_credit_card(post, credit_card)
        post[:payment][:creditCard][:saveCard] = true
        post
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def commit(action, path, params)
        url = url(path)
        response = parse(ssl_request(HTTP_METHOD[action], url, post_data(action, params), headers))

        success = success_from(action, response)
        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(action, path, response),
          test: test?,
          error_code: error_code_from(response, success)
        )
      rescue ResponseError => e
        raise unless e.response.code.to_i == 400

        Response.new(
          false,
          error_message(e),
          {},
          test: test?
        )
      end

      def url(path)
        base_url = test? ? test_url : live_url
        "#{base_url}/#{path}/"
      end

      def success_from(action, response)
        case action
        when 'authorize', 'store'
          response.dig('Payment', 'Status') == STATUS_AUTHORIZED
        when 'purchase'
          response.dig('Payment', 'Status') == STATUS_CAPTURED
        when 'capture'
          response['Status'] == STATUS_CAPTURED
        when 'void'
          [STATUS_VOIDED, STATUS_REFUNDED].include?(response['Status'])
        else
          false
        end
      end

      def message_from(response)
        response.dig('Payment', 'ReasonMessage') || response['ReasonMessage']
      end

      def authorization_from(action, path, response)
        if action == 'store'
          [
            response.dig('Payment', 'PaymentId'),
            response.dig('Payment', 'CreditCard', 'CardToken'),
            response.dig('Payment', 'CreditCard', 'Brand')
          ].compact.join('|')
        elsif %w(capture void).include?(action)
          # return the original transaction identifier
          match = path.match(/\/v2\/sales\/(.+)\/(?:void|capture)/)
          return nil unless match

          match.captures.first
        else
          response.dig('Payment', 'PaymentId')
        end
      end

      def error_code_from(response, success)
        unless success
          code = response.dig('Payment', 'ReasonCode') || response['ReasonCode']
          code&.to_s
        end
      end

      def post_data(action, parameters={})
        JSON.generate(parameters) unless %w(capture void).include?(action)
      end

      def headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'MerchantId' => @merchant_id,
          'MerchantKey' => @merchant_key,
          'RequestId' => (@options[:request_id] || SecureRandom.uuid)
        }
      end

      def error_message(error)
        response_errors = parse(error.response.body)
        return nil unless response_errors.is_a?(Array)

        response_errors.map { |e| "#{e['Code']}: #{e['Message']}" }.join(', ')
      end
    end
  end
end
