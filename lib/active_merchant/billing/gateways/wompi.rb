module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WompiGateway < Gateway
      self.test_url = 'https://sandbox.wompi.co/v1'
      self.live_url = 'https://production.wompi.co/v1'

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

      def refund(money, authorization, options = {})
        post = { amount_in_cents: amount(money).to_i, transaction_id: authorization.to_s }
        commit('refund', post, '/refunds_sync')
      end

      def void(authorization, options = {})
        commit('void', {}, "/transactions/#{authorization}/void")
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
        { 'Authorization': "Bearer #{private_key}" }
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
        installments = options[:installments] ? options[:installments].to_i : 1
        cvc = card.verification_value || nil

        payment_method = {
          type: 'CARD',
          number: card.number,
          exp_month: card.month.to_s.rjust(2, '0'),
          exp_year: card.year.to_s[2..3],
          installments: installments,
          card_holder: card.name
        }
        payment_method[:cvc] = cvc if cvc && !cvc.empty?
        post[:payment_method] = payment_method
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
        response.dig('data', 'status') == 'APPROVED'
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
