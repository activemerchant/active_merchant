require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformGateway < Gateway
      self.test_url = 'https://api.sandbox.paypal.com'
      self.live_url = 'https://api.paypal.com'

      def initialize(options = {})
        requires!(options, :client_id, :secret, :bn_code)
        super(options)
      end

      def purchase(money, payment_method, options = {})
        post = {}
        add_order_id(post, money, options)
        add_amount(post[:purchase_units].first, money, options)
        add_payment_source(post, payment_method, options)

        commit(:post, '/v2/checkout/orders', post, options)
      end

      def store(payment_method, options = {})
        post = { source: {} }
        add_credit_card(post[:source], payment_method, options)

        commit(:post, '/v2/vault/payment-tokens', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)

        commit(:post, "/v2/payments/captures/#{authorization}/refund", post)
      end

      def void(authorization, _options = {})
        commit(:post, "/v2/payments/captures/#{authorization}/refund", {})
      end

      def unstore(paymethod_token, _options = {})
        commit(:delete, "/v2/vault/payment-tokens/#{paymethod_token}", {})
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization: Basic )[\w-]+/, '\1[FILTERED]')
          .gsub(/(Authorization: Bearer )[\w-]+/, '\1[FILTERED]')
          .gsub(/(access_token)\W+[\w-]+/, '\1[FILTERED]')
          .gsub(/(number)\W+\d+/, '\1[FILTERED]')
          .gsub(/(security_code)\W+\d+/, '\1[FILTERED]')
      end

      private

      def add_credit_card(params, payment_method, options)
        params[:card] = {
          type: format_card_brand(payment_method.brand),
          name: payment_method.name,
          number: payment_method.number,
          security_code: payment_method.verification_value,
          expiry: "#{payment_method.year}-#{format(payment_method.month, :two_digits)}",
        }

        if options[:billing_address].present?
          params[:card][:billing_address] = {}

          billing_address = options[:billing_address]
          address_line_1 = billing_address[:address1]
          address_line_1 += " #{billing_address[:address2]}" if billing_address[:address2].present?

          params[:card][:billing_address][:address_line_1] = address_line_1 if address_line_1.present?
          params[:card][:billing_address][:admin_area_1] = billing_address[:state] if billing_address[:state].present?
          params[:card][:billing_address][:admin_area_2] = billing_address[:city] if billing_address[:city].present?

          if billing_address[:zip].present? && billing_address[:country].present?
            params[:card][:billing_address][:postal_code] = billing_address[:zip]
            params[:card][:billing_address][:country_code] = billing_address[:country]
          end

          params[:card].delete(:billing_address) unless
            params[:card][:billing_address].any? { |_, value| value.present? }
        end
      end

      def add_payment_source(post, payment_method, options)
        if payment_method.is_a?(String)
          add_payment_source_token(post, payment_method)
        else
          add_payment_source_credit_card(post, payment_method, options)
        end
      end

      def add_payment_source_token(post, payment_method)
        post[:payment_source] ||= {}
        post[:payment_source][:token] = {
          type: 'PAYMENT_METHOD_TOKEN',
          id: payment_method
        }
      end

      def add_payment_source_credit_card(post, payment_method, options)
        post[:payment_source] ||= {}
        add_credit_card(post[:payment_source], payment_method, options)
      end

      def add_order_id(post, money, options)
        post[:intent] = 'CAPTURE'
        post[:purchase_units] ||= {}
        post[:purchase_units] = [{
          reference_id: options[:order_id]
        }]
      end

      def add_amount(post, money, options)
        post[:amount] = {
          currency_code: options[:currency],
          value: amount(money)
        }
      end

      def access_token
        @access_token ||= begin
          path = '/v1/oauth2/token'
          body = URI.encode_www_form({ 'grant_type' => 'client_credentials' })

          headers = {
            'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:client_id]}:#{@options[:secret]}")),
            'PayPal-Partner-Attribution-Id' => @options[:bn_code],
            'Content-Type' => 'application/x-www-form-urlencoded'
          }

          response = raw_ssl_request(:post, URI.join(base_url, path), body, headers)

          if response.code.to_i == 200
            JSON.parse(response.body)['access_token']
          else
            raise ResponseError.new(response)
          end
        end
      end

      def commit(http_method, path, params, options = {})
        begin
          access_token
        rescue ResponseError => e
          return Response.new(false, e.message)
        end

        url = URI.join(base_url, path)
        body = http_method == :delete ? nil : params.to_json

        raw_response = raw_ssl_request(http_method, url, body, headers(options))
        http_code = raw_response.code.to_i
        response = JSON.parse(handle_response(raw_response))
        success = success_from(http_method, path, http_code, response)

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, response, path),
          avs_result: AVSResult.new(code: processor_response(response)['avs_code']),
          cvv_result: CVVResult.new(processor_response(response)['cvv_code']),
          test: test?
        )
      end

      def processor_response(response)
        return {} unless response['purchase_units']
        response['purchase_units'].first['payments']['captures'].first['processor_response'] || {}
      end

      def format_card_brand(card_brand)
        {
          master: :mastercard,
          american_express: :amex
        }.fetch(card_brand.to_sym, card_brand).to_s
      end

      def success_from(http_method, path, http_code, response)
        if path.start_with?('/v2/vault/payment-tokens')
          case http_method
          when :post
            response['status'] == 'CREATED'
          when :delete
            true
          end
        elsif path.start_with?('/v2/checkout/orders')
          response['status'] == 'COMPLETED'
        elsif path.start_with?('/v2/payments/captures')
          response['status'] == 'COMPLETED'
        end
      end

      def message_from(success, response)
        success ? 'Transaction approved' : response['message']
      end

      def authorization_from(success, response, path)
        return unless success

        case path
        when '/v2/vault/payment-tokens'
          response['id']
        when '/v2/checkout/orders'
          response['purchase_units'].first['payments']['captures'].first['id']
        end
      end

      def handle_response(response)
        case response.code.to_i
        when 200..300
          response.body || '{}'
        else
          raise ResponseError.new(response)
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def headers(options = {})
        {
          'Authorization' => ('Bearer ' + access_token),
          'PayPal-Partner-Attribution-Id' => @options[:bn_code],
          'Content-Type' => 'application/json'
        }.tap do |h|
          h['PayPal-Request-Id'] = options[:order_id] if options[:order_id]
        end
      end
    end
  end
end
