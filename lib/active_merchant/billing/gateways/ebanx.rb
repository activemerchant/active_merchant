module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EbanxGateway < Gateway
      self.supported_countries = %w(BR MX CO CL AR PE)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club elo hipercard]

      self.homepage_url = 'http://www.ebanx.com/'
      self.display_name = 'EBANX'

      class_attribute :gateway
      class_attribute :gateway_version

      VERIFY_AMOUNT_PER_COUNTRY = {
        'br' => 100,
        'ar' => 100,
        'co' => 50000,
        'pe' => 300,
        'mx' => 2000,
        'cl' => 80000
      }

      TAGS = ['Spreedly']

      def initialize(options = {})
        requires!(options, :integration_key)
        @gateway_version = nil

        super
      end

      def purchase(money, payment, options = {})
        @gateway = get_gateway_version(options)

        purchase_payload = @gateway.purchase(amount(money), options[:currency] || currency(money), payment, options)
        commit(:purchase, purchase_payload)
      end

      def authorize(money, payment, options = {})
        @gateway = get_gateway_version(options)

        authorize_payload = @gateway.authorize(amount(money), options[:currency] || currency(money), payment, options)
        commit(:authorize, authorize_payload)
      end

      def capture(money, authorization, options = {})
        @gateway = get_gateway_version(options)

        capture_payload = @gateway.capture(amount(money), authorization, options)
        commit(:capture, capture_payload)
      end

      def refund(money, authorization, options = {})
        @gateway = get_gateway_version(options)

        refund_payload = @gateway.refund(amount(money), authorization, options)
        commit(:refund, refund_payload)
      end

      def void(authorization, options = {})
        @gateway = get_gateway_version(options)

        void_payload = @gateway.void(authorization, options)
        commit(:void, void_payload)
      end

      def store(credit_card, options = {})
        @gateway = get_gateway_version(options)

        void_payload = @gateway.store(credit_card, options)
        commit(:store, void_payload)
      end

      def verify(credit_card, options = {})
        @gateway = get_gateway_version(options)

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(VERIFY_AMOUNT_PER_COUNTRY[@gateway.customer_country(options)], credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def inquire(authorization, options = {})
        @gateway = get_gateway_version(options)
        inquire_payload = @gateway.inquire(authorization)
        commit(:inquire, inquire_payload)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        get_gateway_version(@options)

        if @gateway_version === 'v1'
          transcript.
            gsub(/(integration_key\\?":\\?")(\w*)/, '\1[FILTERED]').
            gsub(/(card_number\\?":\\?")(\d*)/, '\1[FILTERED]').
            gsub(/(card_cvv\\?":\\?")(\d*)/, '\1[FILTERED]')
        else
          transcript.
            gsub(/(number\\?":\\?")(\d*)/, '\1[FILTERED]').
            gsub(/(verification_value\\?":\\?")(\d*)/, '\1[FILTERED]')
        end
      end

      private

      def get_gateway_version(parameters)
        return gateway if gateway

        headers = { 'x-ebanx-client-user-agent': "ActiveMerchant/#{ActiveMerchant::VERSION}" }
        headers['authorization'] = @options[:integration_key]

        processing_type = parameters[:processing_type]

        add_processing_type_to_commit_headers(headers, processing_type) if processing_type == 'local'

        response = parse(ssl_get(get_url(test?), headers))

        @gateway_version = response['gateway'] === 'v2' ? 'v2' : 'v1'
        response['gateway'] === 'v2' ? EbanxV2Gateway.new(@options[:integration_key]) : EbanxV1Gateway.new(@options[:integration_key])
      end

      def get_url(is_test_mode)
        if is_test_mode
          'https://sandbox.ebanxpay.com/channels/spreedly/flow'
        else
          'https://api.ebanxpay.com/channels/spreedly/flow'
        end
      end

      def add_processing_type_to_commit_headers(commit_headers, processing_type)
        commit_headers['x-ebanx-api-processing-type'] = processing_type
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = @gateway.url_for(test?, action, parameters)
        response = parse(ssl_request(@gateway.get_http_method(action), url, @gateway.post_data(action, parameters), @gateway.headers(parameters)))

        success = success_from(action, response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: error_code_from(response, success)
        )
      end

      def success_from(action, response)
        payment_status = response.try(:[], 'payment').try(:[], 'status')

        if %i[purchase capture refund].include?(action)
          payment_status == 'CO'
        elsif action == :authorize
          payment_status == 'PE'
        elsif action == :void
          payment_status == 'CA'
        elsif %i[store inquire].include?(action)
          response.try(:[], 'status') == 'SUCCESS'
        else
          false
        end
      end

      def authorization_from(action, parameters, response)
        if action == :store
          if success_from(action, response)
            "#{response.try(:[], 'token')}|#{response['payment_type_code']}"
          else
            response.try(:[], 'token')
          end
        else
          response.try(:[], 'payment').try(:[], 'hash')
        end
      end

      def message_from(response)
        return response['status_message'] if response['status'] == 'ERROR'

        response.try(:[], 'payment').try(:[], 'transaction_status').try(:[], 'description')
      end

      def convert_to_url_form_encoded(parameters)
        parameters.map do |key, value|
          next if value != false && value.blank?

          "#{key}=#{value}"
        end.compact.join('&')
      end

      def error_code_from(response, success)
        unless success
          return response['status_code'] if response['status'] == 'ERROR'

          response.try(:[], 'payment').try(:[], 'transaction_status').try(:[], 'code')
        end
      end
    end
  end
end