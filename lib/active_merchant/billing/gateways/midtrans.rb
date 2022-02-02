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
        :cstor
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
        expire: 'expire'
      }

      MINIMUM_AUTHORIZE_AMOUNTS = {
        'IDR' => 50
      }

      FRAUD_STATUS_MAPPING = {
        accept: 'accept',
        challenge: 'challenge',
        deny: 'deny'
      }

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
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, options)
        add_customer_data(post, options)
        create_charge(post)
      end

      private

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
        post[:credit_card] = {}
        token_id = tokenize_card(payment)
        post[:credit_card][:token_id] = token_id
        post[:credit_card][:type] = options[:transaction_type] if options[:transaction_type]
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
          JSON.parse(response.body)["token_id"]
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def create_charge(parameters)
        begin
          gateway_response = @midtrans_gateway.charge(parameters)
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
        return nil if %w[200 201].include? status.to_i
        STATUS_CODE_MAPPING[status.to_i]
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
    end
  end
end
