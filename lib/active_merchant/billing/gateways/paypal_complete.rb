require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCompleteGateway < Gateway
      self.test_url = 'https://api-m.sandbox.paypal.com'
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
        token_id = if payment_method.respond_to?(:payment_method_nonce)
                     payment_method.payment_method_nonce
                   else
                     post = { payment_source: {} }
                     add_credit_card(post[:payment_source], payment_method, options)
                     response = commit(:post, '/v3/vault/setup-tokens', post, options)

                     response.params['id']
                   end

        post = { payment_source: {} }
        add_token(post[:payment_source], token_id)
        commit(:post, '/v3/vault/payment-tokens', post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)

        commit(:post, "/v2/payments/captures/#{authorization}/refund", post, options)
      end

      def void(authorization, options = {})
        commit(:post, "/v2/payments/captures/#{authorization}/refund", {}, options)
      end

      def unstore(paymethod_token, _options = {})
        commit(:delete, "/v3/vault/payment-tokens/#{paymethod_token}", {})
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
          brand: format_card_brand(payment_method.brand),
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

      def add_token(params, token_id)
        params[:token] = {
          id: token_id,
          type: "SETUP_TOKEN"
        }
      end

      def add_payment_source(post, vault_id, options)
        post[:payment_source] ||= {}
        payment_source = options[:payment_type] == "paypal_account" ? :paypal : :card
        post[:payment_source][payment_source] = {
          vault_id: vault_id
        }
      end

      def level_2_data(options)
        {
          tax_total: price_object(options[:tax_amount_in_cents], options[:currency])
        }
      end

      def level_3_data(options)
        {}.tap do |hash|
          hash[:shipping_address] = shipping_address(options) unless shipping_address(options).blank?
          hash[:ships_from_postal_code] = options[:shipping_from_zip] if options[:shipping_from_zip]
          hash[:shipping_amount] = price_object(0, options[:currency])
          hash[:discount_amount] = price_object(options[:discount_amount_in_cents], options[:currency])
          hash[:line_items] = line_items(options)
        end
      end

      def shipping_address(options)
        return {} if options[:shipping_address].blank?
        return {} if options[:shipping_address].values.compact.blank?

        {
          address_line_1: options[:shipping_address][:address],
          admin_area_2: options[:shipping_address][:city],
          admin_area_1: options[:shipping_address][:state],
          postal_code: options[:shipping_address][:zip],
          country_code: options[:shipping_address][:country]
        }
      end

      def line_items(options)
        options[:line_items].map do |item|
          {
            name: item[:title],
            description: item[:description],
            quantity: item[:quantity],
            unit_amount: price_object(item[:price_in_cents], options[:currency]),
            tax: price_object(item[:tax_amount_in_cents], options[:currency]),
            discount_amount: price_object(item[:discount_amount_in_cents], options[:currency]),
            total_amount: price_object(item[:total_amount_in_cents], options[:currency]),
            category: physical_retail?(options) ? "PHYSICAL_GOODS" : "DIGITAL_GOODS",
            commodity_code: item[:commodity_code]
          }
        end
      end

      def price_object(price_in_cent, currency)
        {
          currency_code: currency,
          value: amount(price_in_cent)
        }
      end

      def add_order_id(post, _money, options)
        post[:intent] = 'CAPTURE'
        post[:purchase_units] ||= {}
        post[:purchase_units] = [{
                                   reference_id: options[:order_id],
                                   payee: {
                                     merchant_id: @options[:merchant_id]
                                   },
                                   items: line_items(options),
                                   level_2: level_2_data(options),
                                   level_3: level_3_data(options)
                                 }]
      end

      def physical_retail?(options)
        !!options.dig(:metadata, :is_physical)
      end

      def add_amount(post, money, options)
        post[:amount] = {
          currency_code: options[:currency],
          value: amount(money),
          breakdown: {
            item_total: price_object(items_total(options), options[:currency]),
            tax_total: price_object(options[:tax_amount_in_cents], options[:currency]),
            discount: price_object(discount_total(options), options[:currency])
          }
        }
      end

      def items_total(options)
        options[:line_items].sum do |item|
          item[:price_in_cents] * item[:quantity]
        end
      end

      def discount_total(options)
        options[:line_items].sum { |item| item[:discount_amount_in_cents] }
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
        }.fetch(card_brand.to_sym, card_brand).to_s.upcase
      end

      def success_from(http_method, path, http_code, response)
        if path.start_with?('/v3/vault/setup-tokens')
          response['status'] == 'APPROVED'
        elsif path.start_with?('/v3/vault/payment-tokens')
          true
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
        when '/v3/vault/setup-tokens'
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
          'Content-Type' => 'application/json',
          'PayPal-Auth-Assertion' => JWT.encode(
            {
              iss: @options[:client_id],
              payer_id: @options[:merchant_id]
            },
            nil,
            'none'
          )
        }.tap do |h|
          h['PayPal-Request-Id'] = options[:order_id] if options[:order_id]
          if options[:device_data] && options[:device_data][:correlation_id]
            h['PAYPAL-CLIENT-METADATA-ID'] = options[:device_data][:correlation_id]
          end
        end
      end
    end
  end
end
