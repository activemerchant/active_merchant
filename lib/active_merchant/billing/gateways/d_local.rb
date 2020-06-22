module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DLocalGateway < Gateway
      self.test_url = 'https://sandbox.dlocal.com'
      self.live_url = 'https://api.dlocal.com'

      self.supported_countries = %w[AR BR CL CO MX PE UY TR]
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club maestro naranja cabal]

      self.homepage_url = 'https://dlocal.com/'
      self.display_name = 'dLocal'

      def initialize(options={})
        requires!(options, :login, :trans_key, :secret_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_auth_purchase_params(post, money, payment, 'purchase', options)

        commit('purchase', post, options)
      end

      def authorize(money, payment, options={})
        post = {}
        add_auth_purchase_params(post, money, payment, 'authorize', options)

        commit('authorize', post, options)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:authorization_id] = authorization
        add_invoice(post, money, options) if money
        commit('capture', post, options)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:payment_id] = authorization
        post[:notification_url] = options[:notification_url]
        add_invoice(post, money, options) if money
        commit('refund', post, options)
      end

      def void(authorization, options={})
        post = {}
        post[:authorization_id] = authorization
        commit('void', post, options)
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
          gsub(%r((X-Trans-Key: )\w+), '\1[FILTERED]').
          gsub(%r((\"number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"cvv\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      def add_auth_purchase_params(post, money, card, action, options)
        add_invoice(post, money, options)
        post[:payment_method_id] = 'CARD'
        post[:payment_method_flow] = 'DIRECT'
        add_country(post, card, options)
        add_payer(post, card, options)
        add_card(post, card, action, options)
        post[:order_id] = options[:order_id] || generate_unique_id
        post[:description] = options[:description] if options[:description]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_country(post, card, options)
        return unless address = options[:billing_address] || options[:address]

        post[:country] = lookup_country_code(address[:country])
      end

      def lookup_country_code(country_field)
        Country.find(country_field).code(:alpha2).value
      rescue InvalidCountryCodeError
        nil
      end

      def add_payer(post, card, options)
        address = options[:billing_address] || options[:address]
        post[:payer] = {}
        post[:payer][:name] = card.name
        post[:payer][:email] = options[:email] if options[:email]
        post[:payer][:birth_date] = options[:birth_date] if options[:birth_date]
        post[:payer][:phone] = address[:phone] if address && address[:phone]
        post[:payer][:document] = options[:document] if options[:document]
        post[:payer][:document2] = options[:document2] if options[:document2]
        post[:payer][:user_reference] = options[:user_reference] if options[:user_reference]
        post[:payer][:address] = add_address(post, card, options)
      end

      def add_address(post, card, options)
        return unless address = options[:billing_address] || options[:address]

        address_object = {}
        address_object[:state] = address[:state] if address[:state]
        address_object[:city] = address[:city] if address[:city]
        address_object[:zip_code] = address[:zip] if address[:zip]
        address_object[:street] = address[:street] || parse_street(address) if parse_street(address)
        address_object[:number] = address[:number] || parse_house_number(address) if parse_house_number(address)
        address_object
      end

      def parse_street(address)
        return unless address[:address1]

        street = address[:address1].split(/\s+/).keep_if { |x| x !~ /\d/ }.join(' ')
        street.empty? ? nil : street
      end

      def parse_house_number(address)
        return unless address[:address1]

        house = address[:address1].split(/\s+/).keep_if { |x| x =~ /\d/ }.join(' ')
        house.empty? ? nil : house
      end

      def add_card(post, card, action, options={})
        post[:card] = {}
        post[:card][:holder_name] = card.name
        post[:card][:expiration_month] = card.month
        post[:card][:expiration_year] = card.year
        post[:card][:number] = card.number
        post[:card][:cvv] = card.verification_value
        post[:card][:descriptor] = options[:dynamic_descriptor] if options[:dynamic_descriptor]
        post[:card][:capture] = (action == 'purchase')
        post[:card][:installments] = options[:installments] if options[:installments]
        post[:card][:installments_id] = options[:installments_id] if options[:installments_id]
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, options={})
        url = url(action, parameters, options)
        post = post_data(action, parameters)
        begin
          raw = ssl_post(url, post, headers(post, options))
          response = parse(raw)
        rescue ResponseError => e
          raw = e.response.body
          response = parse(raw)
        end

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      # A refund may not be immediate, and return a status_code of 100, "Pending".
      # Since we aren't handling async notifications of eventual success,
      # we count 100 as a success.
      def success_from(action, response)
        return false unless response['status_code']

        %w[100 200 400 600].include? response['status_code'].to_s
      end

      def message_from(action, response)
        response['status_detail'] || response['message']
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(action, response)
        return if success_from(action, response)

        code = response['status_code'] || response['code']
        code&.to_s
      end

      def url(action, parameters, options={})
        "#{(test? ? test_url : live_url)}/#{endpoint(action, parameters, options)}/"
      end

      def endpoint(action, parameters, options)
        case action
        when 'purchase'
          'secure_payments'
        when 'authorize'
          'secure_payments'
        when 'refund'
          'refunds'
        when 'capture'
          'payments'
        when 'void'
          "payments/#{parameters[:authorization_id]}/cancel"
        end
      end

      def headers(post, options={})
        timestamp = Time.now.utc.iso8601
        headers = {
          'Content-Type' => 'application/json',
          'X-Date' => timestamp,
          'X-Login' => @options[:login],
          'X-Trans-Key' => @options[:trans_key],
          'Authorization' => signature(post, timestamp)
        }
        headers.merge('X-Idempotency-Key' => options[:idempotency_key]) if options[:idempotency_key]
        headers
      end

      def signature(post, timestamp)
        content = "#{@options[:login]}#{timestamp}#{post}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @options[:secret_key], content)
        "V2-HMAC-SHA256, Signature: #{digest}"
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end
    end
  end
end
