module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercadopagoGateway < Gateway
      self.test_url = 'https://api.mercadopago.com/sandbox/'
      self.live_url = 'https://api.mercadopago.com/'

      self.supported_countries = ['AR','BR','MX','VE','CO']
      self.default_currency = 'ARS'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :naranja, :nativa, :tarshop, :cencosud, :cabal,  :argencard, :cordial, :cordobesa, :cmr]

      self.homepage_url = 'https://www.mercadopago.com.ar/'
      self.display_name = 'Mercado Pago'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        if options.has_key?(:token)
          @access_token = options[:token]
        else
          requires!(options, :client_id, :client_secret) unless options.has_key?(:token)
          @client_id = options[:client_id]
          @client_secret = options[:client_secret]
        end
        @public_key = options[:public_key]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment,options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        response = commit(:post,"v1/payments?access_token=#{@access_token}", post, options)
      end

      def refund(money, authorization, options={})
        params = {}
        params = {amount: amount(money).to_f} unless money.nil?
        unless authorization.present?
          return ActiveMerchant::Billing::Response.new(
              false,
              'Payment not found',
              {status: 'rejected'},
              authorization: nil,
              test: test?,
              error_code: 404
          )
        end
        commit(:post,"v1/payments/#{authorization}/refunds?access_token=#{@access_token}", params,options)
      end

      def void(authorization, options={})
        commit(:put,"v1/payments/#{authorization}?access_token=#{@access_token}", {status:'cancelled'},options)
      end

      def supports_scrubbing?
        false
      end

      private

      def add_customer_data(post, options)
        post[:payer] = {}
        post[:payer][:email] = options[:email] if options.has_key?(:email)
        post[:payer][:type] = options[:payer_type] if options.has_key?(:payer_type)
        post[:payer][:id] = options[:payer_id] if options.has_key?(:payer_id)
        if options.has_key?(:identification_number)
          post[:payer][:identification] = {number: options[:identification_number]}
          post[:payer][:identification][:type] = options[:identification_type] if options.has_key?(:identification_type)
        end
      end

      def add_address(post, creditcard, options)
        post[:additional_info] = options[:additional_info] if options.has_key?(:additional_info)
        if options[:billing_address]
          billing_address = options[:billing_address]
          post[:additional_info] ||= {}
          payer = {}
          post[:additional_info][:payer] = payer
          payer[:last_name] = billing_address[:name] if billing_address.has_key?(:name)
          payer[:phone] = { number: billing_address[:phone] } if billing_address.has_key?(:phone)
          payer[:address] = {
              street_name: "#{billing_address[:address1]} #{billing_address[:address2]}",
              zip_code: billing_address[:zip]
          }
        end

      end

      def add_invoice(post, money, options)
        post[:transaction_amount] = amount(money).to_f
        post[:installments] = options[:installments] || 1
        post[:description] = (options[:description] || "payment")
        post[:metadata] = options[:metadata] if options.has_key?(:metadata)
        post[:coupon_amount] = options[:coupon_amount] if options.has_key?(:coupon_amount)
        post[:coupon_code] = options[:coupon_code] if options.has_key?(:coupon_code)
        post[:campaign_id] = options[:campaign_id] if options.has_key?(:campaign_id)
        post[:differential_pricing_id] = options[:differential_pricing_id] if options.has_key?(:differential_pricing_id)
        post[:application_fee] = options[:application_fee] if options.has_key?(:application_fee)
        post[:capture] = options[:capture] if options.has_key?(:capture)
        post[:statement_descriptor] = options[:statement_descriptor] if options.has_key?(:statement_descriptor)
        post[:notification_url] = options[:notification_url] if options.has_key?(:notification_url)
      end

      def add_payment(post, payment,options)
        post[:payment_method_id] = payment.try(:brand) || payment[:brand]
        post[:payment_method_id] = 'amex' if post[:payment_method_id] == 'american_express'
        post[:payment_method_id] = 'diners' if post[:payment_method_id] == 'diners_club'
        if !payment.respond_to?(:brand) && payment[:card_token].present?
          post[:token] = payment[:card_token]
        else
          response = get_token(payment,options)
          post[:token] = response.authorization
        end
      end

      def get_token(credit_card, options={})
        card_info = {
            payment_method_id: credit_card.brand,
            email: options[:email],
            cardNumber: credit_card.number,
            security_code: credit_card.verification_value,
            expiration_month: credit_card.month,
            expiration_year: credit_card.year,
            cardholder: {
                name: credit_card.name,
                identification: {
                    number: options[:identification_number],
                    type: options[:identification_type]
                }
            }
        }
        commit(:post, "v1/card_tokens?access_token=#{@access_token}", card_info, options)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(method = :post,action, parameters,options)
        headers = { "Content-Type" => "application/json","x-idempotency-key" => options[:order_id].to_s }
        begin
          response = parse(ssl_request(method,live_url+action, post_data(action, parameters),headers))

          ActiveMerchant::Billing::Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            test: test?,
            error_code: error_code_from(response)
          )
        rescue ResponseError => e
          body = parse(e.response.body)
          ActiveMerchant::Billing::Response.new(
              false,
              message_from(body),
              body,
              authorization: authorization_from(body),
              test: test?,
              error_code: error_code_from(body)
          )
        end

      end

      def success_from(response)
        return !['rejected',404].include?(response['status']) if response.has_key?('status')
        response['id'].present?
      end

      def message_from(response)
        response.has_key?(:message) ? response[:message] : ''
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          response[:error]
        end
      end

      def access_token
        @access_token ||= ask_for_access_token
      end

      def ask_for_access_token
        app_client_values = {
            'grant_type' => 'client_credentials',
            'client_id' => @client_id,
            'client_secret' => @client_secret
        }

        @access_data = RestClient.post("#{url}/oauth/token", build_query(app_client_values), RestClient::MIME_FORM)

        if @access_data['status'] == "200"
          @access_data = @access_data["response"]
          @access_data['access_token']
        else
          raise @access_data.inspect
        end
      end

      def build_query(params)
        URI.escape(params.collect { |k, v| "#{k}=#{v}" }.join('&'))
      end

      def url
        test? ? test_url : live_url
      end
    end
  end
end
