module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WompiGateway < Gateway
      self.test_url = 'https://sync.sandbox.wompi.co/v1'
      self.live_url = 'https://sync.production.wompi.co/v1'

      self.supported_countries = ['CO']
      self.default_currency = 'COP'
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'https://wompi.co/'
      self.display_name = 'Wompi'

      self.money_format = :cents

      def initialize(options = {})
        ## Sandbox keys have prefix pub_test_ and prv_test_
        ## Production keys have prefix pub_prod_ and prv_prod_
        begin
          requires!(options, :prod_private_key, :prod_public_key)
        rescue ArgumentError
          begin
            requires!(options, :test_private_key, :test_public_key)
          rescue ArgumentError
            raise ArgumentError, 'Gateway requires both test_private_key and test_public_key, or both prod_private_key and prod_public_key'
          end
        end
        super
      end

      def purchase(money, payment, options = {})
        post = {
          reference: options[:reference] || generate_reference,
          public_key: public_key
        }
        add_invoice(post, money, options)
        add_card(post, payment, options)

        commit('sale', post, '/transactions_sync')
      end

      def authorize(money, payment, options = {})
        post = {
          public_key: public_key,
          type: 'CARD',
          financial_operation: 'PREAUTHORIZATION'
        }
        add_auth_params(post, money, payment, options)

        commit('authorize', post, '/payment_sources_sync')
      end

      def capture(money, authorization, options = {})
        post = {
          reference: options[:reference] || generate_reference,
          public_key: public_key,
          payment_source_id: authorization.to_i
        }
        add_invoice(post, money, options)
        commit('capture', post, '/transactions_sync')
      end

      def refund(money, authorization, options = {})
        # post = { amount_in_cents: amount(money).to_i, transaction_id: authorization.to_s }
        # commit('refund', post, '/refunds_sync')

        # All refunds will instead be voided. This is temporary.
        void(authorization, options, money)
      end

      def void(authorization, options = {}, money = nil)
        post = money ? { amount_in_cents: amount(money).to_i } : {}
        commit('void', post, "/transactions/#{authorization}/void_sync")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(/(Bearer )\w+/, '\1[REDACTED]').
          gsub(/(\\\"number\\\":\\\")\d+/, '\1[REDACTED]').
          gsub(/(\\\"cvc\\\":\\\")\d+/, '\1[REDACTED]').
          gsub(/(\\\"phone_number\\\":\\\")\+?\d+/, '\1[REDACTED]').
          gsub(/(\\\"email\\\":\\\")\S+\\\",/, '\1[REDACTED]\",').
          gsub(/(\\\"legal_id\\\":\\\")\d+/, '\1[REDACTED]')
      end

      private

      def headers
        {
          'Authorization' => "Bearer #{private_key}",
          'Content-Type' => 'application/json'
        }
      end

      def generate_reference
        SecureRandom.alphanumeric(12)
      end

      def private_key
        test? ? options[:test_private_key] : options[:prod_private_key]
      end

      def public_key
        test? ? options[:test_public_key] : options[:prod_public_key]
      end

      def add_invoice(post, money, options)
        post[:amount_in_cents] = amount(money).to_i
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_card(post, card, options)
        payment_method = {
          type: 'CARD'
        }
        add_basic_card_info(payment_method, card, options)
        post[:payment_method] = payment_method
      end

      def add_auth_params(post, money, card, options)
        data = {
          amount_in_cents: amount(money).to_i,
          currency: (options[:currency] || currency(money))
        }
        add_basic_card_info(data, card, options)
        post[:data] = data
      end

      def add_basic_card_info(post, card, options)
        installments = options[:installments] ? options[:installments].to_i : 1
        cvc = card.verification_value || nil

        post[:number] = card.number
        post[:exp_month] = card.month.to_s.rjust(2, '0')
        post[:exp_year] = card.year.to_s[2..3]
        post[:installments] = installments
        post[:card_holder] = card.name
        post[:cvc] = cvc if cvc && !cvc.empty?
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, endpoint)
        url = (test? ? test_url : live_url) + endpoint
        response = parse(ssl_post(url, post_data(action, parameters), headers))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: nil,
          cvv_result: nil,
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 401, 404, 422
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(response)
        success_statuses.include? response.dig('data', 'status')
      end

      def success_statuses
        %w(APPROVED AVAILABLE)
      end

      def message_from(response)
        response.dig('data', 'status_message') || response.dig('error', 'reason') || response.dig('error', 'messages').to_json
      end

      def authorization_from(response)
        response.dig('data', 'transaction_id') || response.dig('data', 'id') || response.dig('data', 'transaction', 'id')
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        response.dig('error', 'type') unless success_from(response)
      end
    end
  end
end
