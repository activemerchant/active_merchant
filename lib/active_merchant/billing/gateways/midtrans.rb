begin
  require 'veritrans'
rescue LoadError
  raise 'Could not load the veritrans gem.  Use `gem install veritrans` to install it.'
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MidtransGateway < Gateway
      self.test_url = 'https://api.sandbox.midtrans.com/v2'
      self.live_url = 'https://api.midtrans.com/v2'
      self.supported_countries = ['ID']
      self.default_currency = 'IDR'

      # https://support.midtrans.com/hc/en-us/articles/204379640-Which-payment-methods-do-Midtrans-currently-support-
      self.supported_cardtypes = [:visa, :master, :jcb, :american_express]
      self.homepage_url = 'https://midtrans.com/'
      self.display_name = 'Midtrans'

      SUPPORTED_PAYMENT_METHODS = [
        :credit_card, 
        :bank_transfer, 
        :echannel,
        :bca_klikpay, 
        :bca_klikbca, 
        :mandiri_clickpay, 
        :bri_epay, 
        :cimb_clicks,
        :telkomsel_cash, 
        :xl_tunai, 
        :indosat_dompetku, 
        :mandiri_ecash, 
        :cstor,
        :gopay,
        :shopeepay
      ]

      STATUS_CODE_MAPPING = {
        200 => "SUCCESS",
        201 => "PENDING",
        202 => "DENIED",

        400 => "VALIDATION_ERROR",
        401 => "UNAUTHORIZED_TRANSACTION",
        402 => "PAYMENT_TYPE_ACCESS_DENIED",
        403 => "INVALID_REQUEST_FORMAT",
        404 => "RESOURCE_NOT_FOUND",
        405 => "HTTP_METHOD_NOT_ALLOWED",
        406 => "DUPLICATED_ORDER_ID",
        407 => "EXPIRED_TRANSACTION",
        408 => "INVALID_DATA_TYPE",
        409 => "TOO_MANY_REQUESTS_FOR_SAME_CARD",
        410 => "ACCOUNT_DEACTIVATED",
        411 => "MISSING_TOKEN_ID",
        412 => "CANNOT_MODIFY_TRANSACTION",
        413 => "MALFORMED_REQUEST",
        414 => "REFUND_REECTED_INSUFFICIENT_FUNDS",
        429 => "RATELIMIT_EXCEEDED",

        500 => "INTERNAL_SERVER_ERROR",
        501 => "FEATURE_UNAVAILABLE",
        502 => "BANK_SERVER_CONNECTION_FAILURE",
        503 => "BANK_SERVER_CONNECTION_FAILURE",
        504 => "FRAUD_DETECTION_UNAVAILABLE",
        505 => "VA_CREATION_FAILED"
      }

      TRANSACTION_STATUS_MAPPING = {
        capture: 'capture',
        deny: 'deny',
        authorize: 'authorize',
        cancel: 'cancel',
        expire: 'expire',
        refund: 'refund',
        pending: 'pending'
      }

      MINIMUM_AUTHORIZE_AMOUNTS = {
        'IDR' => 50
      }

      FRAUD_STATUS_MAPPING = {
        accept: 'accept',
        challenge: 'challenge',
        deny: 'deny'
      }

      MISSING_AUTHORIZATION_MESSAGE = "Missing required parameter: authorization"
      CARD_TOKEN_CREATION_SUCCESSFUL = "CARD_TOKEN_CREATION_SUCCESSFUL"
      CARD_TOKEN_CREATION_FAILED = "CARD_TOKEN_CREATION_FAILED"

      GOPAY = "gopay"
      SHOPEEPAY = "shopeepay"
      QRIS = "qris"
      CREDIT_CARD = "credit_card"


      def initialize(options={})
        requires!(options, :client_key, :server_key)
        super
        @midtrans_gateway = Midtrans
        @midtrans_gateway.config.client_key = options[:client_key]
        @midtrans_gateway.config.server_key = options[:server_key]
        @midtrans_gateway.logger = options[:logger]
      end

      def purchase(money, payment, options={})
        post = {}
        configure_notification_url(options)
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_metadata(post, options)
        commit("purchase", post)
      end

      def authorize(money, payment, options={})
        options[:transaction_type] = TRANSACTION_STATUS_MAPPING[:authorize]
        purchase(money, payment, options)
      end

      def capture(money, authorization, options={})
        raise ArgumentError.new(MISSING_AUTHORIZATION_MESSAGE) if authorization.nil?
        post = {}
        add_authorization(post, money, authorization)
        commit("capture", post)
      end

      def void(authorization, options={})
        raise ArgumentError.new(MISSING_AUTHORIZATION_MESSAGE) if authorization.nil?
        configure_notification_url(options)
        post = {}
        post[:transaction_id] = authorization
        commit("void", post)
      end

      def refund(money, authorization, options={})
        raise ArgumentError.new(MISSING_AUTHORIZATION_MESSAGE) if authorization.nil?
        post = {}
        contruct_refund_request(post, money, authorization, options)
        commit("refund", post)
      end

      def store(payment, options={})
        options[:save_token_id] = true
        options[:payment_type] = CREDIT_CARD
        options[:order_id] = generate_unique_id()
        MultiResponse.run(:use_first_response) do |r|
          r.process { token_response_for(authorize(MINIMUM_AUTHORIZE_AMOUNTS['IDR'], payment, options).params) }
          r.process(:ignore_result) { void(r.params["transaction_id"], options) }
        end
      end

      def verify_credentials()
        transaction_details = {
          :gross_amount => MINIMUM_AUTHORIZE_AMOUNTS['IDR'],
          :order_id => generate_unique_id()
        }
        options = {
          :transaction_details => transaction_details
        }
        commit('verify_credentials', options)
      end

      private

      def add_metadata(post, options)
        post[:metadata] = options[:metadata] if options[:metadata]
      end

      def configure_notification_url(options)
        @midtrans_gateway.config.override_notif_url = options[:notification_url] if options[:notification_url]
      end

      def add_customer_data(post, options)
        post[:customer_details] = options['customer_details']
      end

      def add_address(post, options)
        customer_details = post[:customer_details] = {}
        customer_details[:billing_address] = options[:billing_address]
        customer_details[:shipping_address] = options[:shipping_address] || options[:billing_address]
      end

      def add_invoice(post, money, options)
        post[:transaction_details] = {
          gross_amount: money,
          order_id: options[:order_id]
        }
        post[:item_details] = options[:item_details]
      end

      def add_payment(post, payment, options)
        post[:payment_type] = options[:payment_type]
        if post[:payment_type] == CREDIT_CARD
          post[:credit_card] = {}
          token_id = nil
          if payment.is_a?(WalletToken)
            token_id = payment.token if payment.token
          else
            token_id = tokenize_card(payment)["token_id"]
          end
          post[:credit_card][:token_id] = token_id
          post[:credit_card][:authentication] = options[:enable_3ds] if options[:enable_3ds]
          post[:credit_card][:type] = options[:transaction_type] if options[:transaction_type]
          post[:credit_card][:save_token_id] = options[:save_token_id] if options[:save_token_id]
        elsif post[:payment_type] == GOPAY
          post[:gopay] = {}
          post[:gopay][:enable_callback] = true if options[:callback_url]
          post[:gopay][:callback_url] = options[:callback_url] if options[:callback_url]
        elsif post[:payment_type] == SHOPEEPAY
          post[:shopeepay] = {}
          post[:shopeepay][:enable_callback] = true if options[:callback_url]
          post[:shopeepay][:callback_url] = options[:callback_url] if options[:callback_url]
        elsif post[:payment_type] == QRIS
          post[:qris] = {}
          post[:qris][:acquirer] = options[:acquirer] if options[:acquirer]
        end
      end

      def url()
        "#{(test? ? test_url : live_url)}"
      end

      def tokenize_card(card)
        query_params = {
          card_number: card.number,
          card_cvv: card.verification_value,
          card_exp_month: card.month,
          card_exp_year: card.year,
          client_key: @midtrans_gateway.config.client_key
        }
        @uri = URI.parse("#{url()}/token?#{URI.encode_www_form(query_params)}")
        begin
          response = Net::HTTP.get_response(@uri)
          JSON.parse(response.body)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def add_authorization(post, money, authorization)
        post[:transaction_id] = authorization
        post[:amount] = money
      end

      def contruct_refund_request(post, money, authorization, options={})
        post[:transaction_id] = authorization
        post[:details] = {}
        post[:details][:amount] = money if money
        post[:details][:reason] = options[:reason] if options[:reason]
        post[:details][:refund_key] = options[:order_id] if options[:order_id]
      end

      def commit(action, parameters)
        begin
          case action
          when "purchase"
            gateway_response = @midtrans_gateway.charge(parameters)
          when "capture"
            gateway_response = @midtrans_gateway.capture(parameters[:transaction_id], parameters[:amount])
          when "void"
            gateway_response = @midtrans_gateway.cancel(parameters[:transaction_id])
          when "refund"
            gateway_response = @midtrans_gateway.refund(parameters[:transaction_id], parameters[:details])
          when "verify_credentials"
            gateway_response = @midtrans_gateway.create_snap_token(parameters)
          end
          response_for(gateway_response)
        rescue MidtransError => error
          error_response_for(error)
        end
      end

      def success_from(gateway_response)
        gateway_response.success?
      end

      def message_from(gateway_response)
        gateway_response.status_message
      end

      def authorization_from(gateway_response)
        gateway_response.transaction_id
      end

      def error_code_from(status)
        if [200, 201].include?(status.to_i)
          return nil
        else
          return STATUS_CODE_MAPPING[status.to_i]
        end
      end

      def error_response_for(gateway_response)
        response = eval(gateway_response.data)
        Response.new(
          false,
          response["status_message"],
          response,
          authorization: response["id"],
          test: test?,
          error_code: error_code_from(gateway_response.status)
        )
      end

      def response_for(gateway_response)
        Response.new(
          success_from(gateway_response),
          message_from(gateway_response),
          gateway_response.data,
          authorization: authorization_from(gateway_response),
          test: test?,
          error_code: error_code_from(gateway_response.status_code)
        )
      end

      def token_response_for(gateway_response)
        success = ["200", "201"].include?(gateway_response["status_code"])
        message = success ? CARD_TOKEN_CREATION_SUCCESSFUL: CARD_TOKEN_CREATION_FAILED
        Response.new(
          success,
          message,
          gateway_response,
          authorization: success ? gateway_response["saved_token_id"]: nil,
          test: test?,
          error_code: error_code_from(gateway_response["status_code"])
        )
      end
    end
  end
end
