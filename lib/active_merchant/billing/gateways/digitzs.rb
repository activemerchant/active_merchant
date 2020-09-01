module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DigitzsGateway < Gateway
      include Empty

      self.test_url = 'https://beta.digitzsapi.com/sandbox'
      self.live_url = 'https://beta.digitzsapi.com/v3'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]
      self.money_format = :cents

      self.homepage_url = 'https://digitzs.com'
      self.display_name = 'Digitzs'

      def initialize(options={})
        requires!(options, :app_key, :api_key)
        super
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process { commit('auth/token', app_token_request(options)) }
          r.process { commit('payments', purchase_request(money, payment, options), options.merge({ app_token: app_token_from(r) })) }
        end
      end

      def refund(money, authorization, options={})
        MultiResponse.run do |r|
          r.process { commit('auth/token', app_token_request(options)) }
          r.process { commit('payments', refund_request(money, authorization, options), options.merge({ app_token: app_token_from(r) })) }
        end
      end

      def store(payment, options = {})
        MultiResponse.run do |r|
          r.process { commit('auth/token', app_token_request(options)) }
          options[:app_token] = app_token_from(r)

          if options[:customer_id].present?
            customer_id = check_customer_exists(options)

            if customer_id
              r.process { add_credit_card_to_customer(payment, options) }
            else
              r.process { add_customer_with_credit_card(payment, options) }
            end
          else
            r.process { add_customer_with_credit_card(payment, options) }
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer ).+), '\1[FILTERED]').
          gsub(%r((X-Api-Key: )\w+), '\1[FILTERED]').
          gsub(%r((\"id\\\":\\\").+), '\1[FILTERED]').
          gsub(%r((\"appKey\\\":\\\").+), '\1[FILTERED]').
          gsub(%r((\"appToken\\\":\\\").+), '\1[FILTERED]').
          gsub(%r((\"code\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"number\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      def new_post
        {
          data: {
            attributes: {}
          }
        }
      end

      def add_split(post, options)
        return unless options[:payment_type] == 'card_split' || options[:payment_type] == 'token_split'

        post[:data][:attributes][:split] = {
          merchantId: options[:split_merchant_id],
          amount: amount(options[:split_amount])
        }
      end

      def add_payment(post, payment, options)
        if payment.is_a? String
          customer_id, token = split_authorization(payment)
          post[:data][:attributes][:token] = {
            customerId: customer_id,
            tokenId: token
          }
        else
          post[:data][:attributes][:card] = {
            type: payment.brand,
            holder: payment.name,
            number: payment.number,
            expiry: expdate(payment),
            code: payment.verification_value
          }
        end
      end

      def add_transaction(post, money, options)
        post[:data][:attributes][:transaction] = {
          amount: amount(money),
          currency: (options[:currency] || currency(money)),
          invoice: options[:order_id] || generate_unique_id
        }
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:data][:attributes][:billingAddress] = {
            line1: address[:address1] || '',
            line2: address[:address2] || '',
            city: address[:city] || '',
            state: address[:state] || '',
            zip: address[:zip] || '',
            country: address['country'] || 'USA'
          }
        end
      end

      def app_token_request(options)
        post = new_post
        post[:data][:type] = 'auth'
        post[:data][:attributes] = { appKey: @options[:app_key] }

        post
      end

      def purchase_request(money, payment, options)
        post = new_post
        post[:data][:type] = 'payments'
        post[:data][:attributes][:merchantId] = options[:merchant_id]
        post[:data][:attributes][:paymentType] = determine_payment_type(payment, options)
        add_split(post, options)
        add_payment(post, payment, options)
        add_transaction(post, money, options)
        add_address(post, options)

        post
      end

      def refund_request(money, authorization, options)
        post = new_post
        post[:data][:type] = 'payments'
        post[:data][:attributes][:merchantId] = options[:merchant_id]
        post[:data][:attributes][:paymentType] = 'cardRefund'
        post[:data][:attributes][:originalTransaction] = {id: authorization}
        add_transaction(post, money, options)

        post
      end

      def create_customer_request(payment, options)
        post = new_post
        post[:data][:type] = 'customers'
        post[:data][:attributes] = {
          merchantId: options[:merchant_id],
          name: payment.name,
          externalId: SecureRandom.hex(16)
        }

        post
      end

      def create_token_request(payment, options)
        post = new_post
        post[:data][:type] = 'tokens'
        post[:data][:attributes] = {
          tokenType: 'card',
          customerId: options[:customer_id],
          label: 'Credit Card'
        }
        add_payment(post, payment, options)
        add_address(post, options)

        post
      end

      def check_customer_exists(options = {})
        url = (test? ? test_url : live_url)
        response = parse(ssl_get(url + "/customers/#{options[:customer_id]}", headers(options)))

        return response.try(:[], 'data').try(:[], 'customerId') if success_from(response)

        return nil
      end

      def add_credit_card_to_customer(payment, options = {})
        commit('tokens', create_token_request(payment, options), options)
      end

      def add_customer_with_credit_card(payment, options = {})
        customer_response = commit('customers', create_customer_request(payment, options), options)
        options[:customer_id] = customer_response.authorization
        commit('tokens', create_token_request(payment, options), options)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, options={})
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url + "/#{action}", parameters.to_json, headers(options)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: avs_result_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response)),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['errors'].nil? && response['message'].nil?
      end

      def message_from(response)
        return response['message'] if response['message']
        return 'Success' if success_from(response)

        response['errors'].map { |error_hash| error_hash['detail'] }.join(', ')
      end

      def authorization_from(response)
        if customer_id = response.try(:[], 'data').try(:[], 'attributes').try(:[], 'customerId')
          "#{customer_id}|#{response.try(:[], 'data').try(:[], 'id')}"
        else
          response.try(:[], 'data').try(:[], 'id')
        end
      end

      def avs_result_from(response)
        response.try(:[], 'data').try(:[], 'attributes').try(:[], 'transaction').try(:[], 'avsResult')
      end

      def cvv_result_from(response)
        response.try(:[], 'data').try(:[], 'attributes').try(:[], 'transaction').try(:[], 'codeResult')
      end

      def app_token_from(response)
        response.params.try(:[], 'data').try(:[], 'attributes').try(:[], 'appToken')
      end

      def headers(options)
        headers = {
          'Content-Type' => 'application/json',
          'x-api-key' => @options[:api_key]
        }

        headers['Authorization'] = "Bearer #{options[:app_token]}" if options[:app_token]
        headers
      end

      def error_code_from(response)
        unless success_from(response)
          response['errors'].nil? ? response['message'] : response['errors'].map { |error_hash| error_hash['code'] }.join(', ')
        end
      end

      def split_authorization(authorization)
        customer_id, token = authorization.split('|')
        [customer_id, token]
      end

      def determine_payment_type(payment, options)
        return 'cardSplit' if options[:payment_type] == 'card_split'
        return 'tokenSplit' if options[:payment_type] == 'token_split'
        return 'token' if payment.is_a? String

        'card'
      end

      def handle_response(response)
        case response.code.to_i
        when 200..499
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
