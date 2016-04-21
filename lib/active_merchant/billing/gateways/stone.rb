module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StoneGateway < Gateway
      self.live_url = 'https://transaction.stone.com.br/Sale/'
      self.test_url = self.live_url

      self.supported_countries = ['BR']
      self.default_currency = 'BR'
      self.supported_cardtypes = [:visa, :master]
      self.money_format = :cents

      self.homepage_url = 'http://www.stone.com.br/'
      self.display_name = 'Stone Ecommerce'

      def initialize(options={})
        requires!(options, :merchant_key)
        @merchant_key = options[:merchant_key]
        super
      end

      def purchase(money, payment, options={})
        options[:operation] = 'AuthAndCapture'
        request_sale(money, payment, options)
      end

      def authorize(money, payment, options={})
        options[:operation] = 'AuthOnly'
        request_sale(money, payment, options)
      end

      def request_sale(money, payment, options={})
        post = {}
        add_payment(post, payment, options)
        add_invoice(post, money, options)

        commit(:sale, post)
      end

      def capture(money, params, options={})
        post = {}
        add_transaction_information(post, money, params)
        commit(:capture, post)
      end

      # Stone API right now use cancel to make a refund
      def void(money, params, options={})
        post = {}
        add_transaction_information(post, money, params)
        commit(:cancel, post)
      end
      alias_method :refund, :void

      def verify(credit_card, options={})
        options[:money] ||= 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(options[:money], credit_card, options) }
          r.process(:ignore_result) { void(options[:money], r.params, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(CreditCardNumber\\":\\")\d+/, '\1[FILTERED]')
          .gsub(/(SecurityCode\\":\\")\d+/, '\1[FILTERED]')
          .gsub(@merchant_key, '[FILTERED]')
      end

      private
      def add_transaction_information(post, money, params)
        params.symbolize_keys!

        post[:request_key] = params[:request_key]
        post[:credit_card_transaction_collection] = [{
          amount_in_cents: amount(money),
          transaction_key: params[:credit_card_transaction_result_collection][0][:transaction_key],
          transaction_reference: params[:credit_card_transaction_result_collection][0][:transaction_reference]
        }]
        post[:order_key] = params[:order_result][:order_key]
      end

      def add_invoice(post, money, options)
        requires!(options, :order_id)

        post[:credit_card_transaction_collection][0][:transaction_reference] = options[:order_id]
        post[:credit_card_transaction_collection][0][:amount_in_cents] = amount(money)
      end

      def add_payment(post, payment, options)
        requires!(options, :operation)

        creditcard = {}
        creditcard[:credit_card_brand] = payment.brand
        creditcard[:credit_card_number] = payment.number
        creditcard[:exp_month] = payment.expiry_date.month
        creditcard[:exp_year] = payment.expiry_date.year
        creditcard[:holder_name] = payment.name
        creditcard[:security_code] = payment.verification_value

        opt = {}
        opt[:payment_method_code] = test? ? 1 : 0

        creditcard_transaction = {}
        creditcard_transaction[:credit_card] = creditcard
        creditcard_transaction[:options] = opt
        creditcard_transaction[:credit_card_operation] = options[:operation]

        post[:credit_card_transaction_collection] = [creditcard_transaction]
      end

      def parse(body)
        JSON.parse(body).deep_transform_keys{ |key| key.underscore.to_sym }
      end

      def commit(action, parameters)
        response = send("do_#{action}", parameters)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def do_sale(parameters)
        parse(ssl_post(self.live_url, post_data(parameters)))
      end

      def do_capture(parameters)
        parse(ssl_post("#{self.live_url}/Capture", post_data(parameters)))
      end

      def do_cancel(parameters)
        parse(ssl_post("#{self.live_url}/Cancel", post_data(parameters)))
      end

      def ssl_post(url, data, headers = {})
        headers['MerchantKey'] = @merchant_key
        headers['Accept'] = 'application/json'
        headers['Content-Type'] = 'application/json'
        begin
          super
        rescue ResponseError => e
          error_response_for(e.response.code, e.message)
        end
      end

      def success_from(response)
        response[:error_report].nil? &&
        response[:credit_card_transaction_result_collection].any?  &&
        response[:credit_card_transaction_result_collection][0][:success]
      end

      def message_from(response)
        if response[:credit_card_transaction_result_collection].any?
          response[:credit_card_transaction_result_collection][0][:acquirer_message].split('|').last
        elsif response[:error_report].present?
          response[:error_report][:error_item_collection][0][:description]
        else
          "Erro no processamento."
        end
      end

      def authorization_from(response)
        success_from(response) ? response[:credit_card_transaction_result_collection][0][:transaction_key] : nil
      end

      def post_data(parameters = {})
        parameters.deep_transform_keys{ |key| key.to_s.camelize }.to_json
      end

      def error_response_for(code, message)
        {
          'ErrorReport': {
            'ErrorItemCollection':[{
              'Description': message,
              'ErrorCode': code
            }]
          },
          'CreditCardTransactionResultCollection': []
        }.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          nil
        end
      end
    end
  end
end
