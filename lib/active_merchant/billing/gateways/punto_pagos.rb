require 'active_merchant/billing/gateways/punto_pagos/authorization.rb'
require 'active_merchant/billing/gateways/punto_pagos/request.rb'
require 'active_merchant/billing/gateways/punto_pagos/purchase_request.rb'
require 'active_merchant/billing/gateways/punto_pagos/status_request.rb'
require 'active_merchant/billing/gateways/punto_pagos/response.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PuntoPagosGateway < Gateway
      self.test_url = 'http://sandbox.puntopagos.com'
      self.live_url = 'https://www.puntopagos.com'

      self.supported_countries = %w(CL)
      self.default_currency = 'CLP'
      self.currencies_without_fractions = %w(CLP)
      self.money_format = :cents

      self.homepage_url = 'https://www.puntopagos.com'
      self.display_name = 'Punto Pagos'

      SUCCESS_CODE = '00'
      ERROR_CODE = '99'

      STANDARD_ERROR_CODE_MAPPING = {
        ERROR_CODE => STANDARD_ERROR_CODE[:processing_error],
        '1' => STANDARD_ERROR_CODE[:processing_error],
        '2' => STANDARD_ERROR_CODE[:processing_error],
        '6' => STANDARD_ERROR_CODE[:processing_error],
        '7' => STANDARD_ERROR_CODE[:processing_error]
      }

      PAYMENT_METHOD_CODE_MAPPING = {
        presto: 2,
        webpay_transbank: 3,
        banco_chile: 4,
        bci: 5,
        tbanc: 6,
        banco_estado: 7,
        bbva: 16,
        ripley: 10,
        paypal: 15
      }

      def initialize(options = {})
        requires!(options, :key, :secret)
        super
      end

      def setup_purchase(money, params = {})
        requires!(params, :trx_id)

        post = {}
        add_invoice(post, money, params)
        add_payment_method(post, params)
        add_trx_id(post, params)
        add_gateway_config(post)

        request = PuntoPagos::PurchaseRequest.new(post)
        response = parse(ssl_post(request.endpoint, request.data, request.headers))
        build_response(response)
      end

      def details_for(params)
        requires!(params, :token, :trx_id, :amount)
        add_gateway_config(params)

        request = PuntoPagos::StatusRequest.new(params)
        response = parse(ssl_get(request.endpoint, request.headers))
        build_response(response)
      end

      def redirect_url_for(token)
        "#{url}/transaccion/procesar/#{token}"
      end

      def notificate(params = {})
        validate_notification_params!(params)
        response = details_for(params)

        if response.success?
          { respuesta: SUCCESS_CODE, token: response.token }
        else
          { respuesta: ERROR_CODE, error: response.message, token: response.token }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(/(Autorizacion: ).+[^\r\n]/, '\1[FILTERED]')
      end

      private

      def validate_notification_params!(params)
        requires!(params, :authorization, :timestamp, :token, :trx_id, :amount)

        signature = PuntoPagos::Authorization.new(options).sign(
          'transaccion/notificacion',
          params[:token],
          params[:trx_id],
          "%0.2f" % params[:amount].to_s.to_i,
          params[:timestamp]
        )

        raise StandardError, 'Invalid notification signature' if signature != params[:authorization]
      end

      def add_invoice(post, money, params)
        post[:amount] = localized_amount(money, allowed_currency(params))
      end

      def add_payment_method(post, params)
        return if params[:payment_method].blank?
        code = PAYMENT_METHOD_CODE_MAPPING[params[:payment_method].to_sym]
        raise ArgumentError.new("Invalid payment type: #{params[:payment_method]}") unless code
        post[:payment_method] = code
      end

      def add_trx_id(post, params)
        post[:trx_id] = params[:trx_id]
      end

      def add_gateway_config(post)
        post[:url] = url
        post[:key] = options[:key]
        post[:secret] = options[:secret]
      end

      def allowed_currency(params)
        provided_currency = params[:currency] || default_currency
        return provided_currency if provided_currency == 'CLP'
        raise ArgumentError.new("Unsupported currency: #{provided_currency}")
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def url
        test? ? test_url : live_url
      end

      def build_response(raw_response)
        PuntoPagos::Response.new(
          success_from(raw_response),
          message_from(raw_response),
          raw_response,
          test: test?,
          error_code: error_code_from(raw_response),
          authorization: authorization_from(raw_response)
        )
      end

      def success_from(response)
        response['respuesta'] == SUCCESS_CODE
      end

      def message_from(response)
        return 'Success' if success_from(response)
        response['error']
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['respuesta']]
      end

      def authorization_from(response)
        response['token']
      end
    end
  end
end
