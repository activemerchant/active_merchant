require 'active_merchant/billing/gateways/cecabank/cecabank_common'

module ActiveMerchant
  module Billing
    class CecabankJsonGateway < Gateway
      include CecabankCommon

      CECA_ACTIONS_DICTIONARY = {
        purchase: :REST_AUTORIZACION,
        authorize: :REST_PREAUTORIZACION,
        capture: :REST_COBRO_PREAUTORIZACION,
        refund: :REST_DEVOLUCION,
        void: :REST_ANULACION
      }.freeze

      CECA_REASON_TYPES = {
        installment: :I,
        recurring: :R,
        unscheduled: :C
      }.freeze

      CECA_INITIATOR = {
        merchant: :N,
        cardholder: :S
      }.freeze

      CECA_SCA_TYPES = {
        low_value_exemption: :LOW,
        transaction_risk_analysis_exemption: :TRA,
        nil: :NONE
      }.freeze

      self.test_url = 'https://tpv.ceca.es/tpvweb/rest/procesos/'
      self.live_url = 'https://pgw.ceca.es/tpvweb/rest/procesos/'

      def authorize(money, creditcard, options = {})
        handle_purchase(:authorize, money, creditcard, options)
      end

      def capture(money, identification, options = {})
        authorization, operation_number, _network_transaction_id = identification.split('#')

        post = {}
        options[:operation_number] = operation_number
        add_auth_invoice_data(:capture, post, money, authorization, options)

        commit('compra', post)
      end

      def purchase(money, creditcard, options = {})
        handle_purchase(:purchase, money, creditcard, options)
      end

      def void(identification, options = {})
        authorization, operation_number, money, _network_transaction_id = identification.split('#')
        options[:operation_number] = operation_number
        handle_cancellation(:void, money.to_i, authorization, options)
      end

      def refund(money, identification, options = {})
        authorization, operation_number, _money, _network_transaction_id = identification.split('#')
        options[:operation_number] = operation_number
        handle_cancellation(:refund, money, authorization, options)
      end

      def scrub(transcript)
        before_message = transcript.gsub(%r(\\\")i, "'").scan(/{[^>]*}/).first.gsub("'", '"')
        request_data = JSON.parse(before_message)
        params =  decode_params(request_data['parametros']).
                  gsub(%r(("pan\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
                  gsub(%r(("caducidad\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
                  gsub(%r(("cvv2\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
                  gsub(%r(("csc\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
        request_data['parametros'] = encode_params(params)

        before_message = before_message.gsub(%r(\")i, '\\\"')
        after_message = request_data.to_json.gsub(%r(\")i, '\\\"')
        transcript.sub(before_message, after_message)
      end

      private

      def handle_purchase(action, money, creditcard, options)
        post = { parametros: { accion: CECA_ACTIONS_DICTIONARY[action] } }

        add_invoice(post, money, options)
        add_creditcard(post, creditcard)
        add_stored_credentials(post, creditcard, options)
        add_three_d_secure(post, options)

        commit('compra', post)
      end

      def handle_cancellation(action, money, authorization, options = {})
        post = {}
        add_auth_invoice_data(action, post, money, authorization, options)

        commit('anulacion', post)
      end

      def add_auth_invoice_data(action, post, money, authorization, options)
        params = post[:parametros] ||= {}
        params[:accion] = CECA_ACTIONS_DICTIONARY[action]
        params[:referencia] = authorization

        add_invoice(post, money, options)
      end

      def add_encryption(post)
        post[:cifrado] = CECA_ENCRIPTION
      end

      def add_signature(post, params_encoded, options)
        post[:firma] = Digest::SHA2.hexdigest(@options[:cypher_key].to_s + params_encoded)
      end

      def add_merchant_data(post)
        params = post[:parametros] ||= {}

        params[:merchantID] = @options[:merchant_id]
        params[:acquirerBIN] = @options[:acquirer_bin]
        params[:terminalID] = @options[:terminal_id]
      end

      def add_invoice(post, money, options)
        post[:parametros][:numOperacion] = options[:operation_number] || options[:order_id]
        post[:parametros][:importe] = amount(money)
        post[:parametros][:tipoMoneda] = CECA_CURRENCIES_DICTIONARY[options[:currency] || currency(money)].to_s
        post[:parametros][:exponente] = 2.to_s
      end

      def add_creditcard(post, creditcard)
        params = post[:parametros] ||= {}

        params[:pan] = creditcard.number
        params[:caducidad] = strftime_yyyymm(creditcard)
        params[:cvv2] = creditcard.verification_value
        params[:csc] = creditcard.verification_value if CreditCard.brand?(creditcard.number) == 'american_express'
      end

      def add_stored_credentials(post, creditcard, options)
        return unless stored_credential = options[:stored_credential]

        return if options[:exemption_type].blank? && !(stored_credential[:reason_type] && stored_credential[:initiator])

        params = post[:parametros] ||= {}
        params[:exencionSCA] = 'MIT'

        requires!(stored_credential, :reason_type, :initiator)
        reason_type = CECA_REASON_TYPES[stored_credential[:reason_type].to_sym]
        initiator = CECA_INITIATOR[stored_credential[:initiator].to_sym]
        params[:tipoCOF] = reason_type
        params[:inicioRec] = initiator
        if initiator == :S
          requires!(options, :recurring_frequency)
          params[:finRec] = options[:recurring_end_date] || strftime_yyyymm(creditcard)
          params[:frecRec] = options[:recurring_frequency]
        end

        params[:mmppTxId] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
      end

      def add_three_d_secure(post, options)
        params = post[:parametros] ||= {}
        return unless three_d_secure = options[:three_d_secure]

        params[:exencionSCA] ||= CECA_SCA_TYPES[options[:exemption_type]&.to_sym]
        three_d_response = {
          exemption_type: options[:exemption_type],
          three_ds_version: three_d_secure[:version],
          authentication_value: three_d_secure[:cavv],
          directory_server_transaction_id: three_d_secure[:ds_transaction_id],
          acs_transaction_id: three_d_secure[:acs_transaction_id],
          authentication_response_status: three_d_secure[:authentication_response_status],
          three_ds_server_trans_id: three_d_secure[:three_ds_server_trans_id],
          ecommerce_indicator: three_d_secure[:eci],
          enrolled: three_d_secure[:enrolled]
        }

        three_d_response.merge!({ amount: post[:parametros][:importe] })

        params[:ThreeDsResponse] = three_d_response.to_json
      end

      def commit(action, post, method = :post)
        auth_options = {
          operation_number: post[:parametros][:numOperacion],
          amount: post[:parametros][:importe]
        }

        add_encryption(post)
        add_merchant_data(post)

        params_encoded = encode_post_parameters(post)
        add_signature(post, params_encoded, options)

        response = parse(ssl_request(method, url(action), post.to_json, headers))
        response[:parametros] = parse(response[:parametros]) if response[:parametros]

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, auth_options),
          network_transaction_id: network_transaction_id_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def url(action)
        (test? ? self.test_url : self.live_url) + action
      end

      def host
        URI.parse(url('')).host
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Host' => host
        }
      end

      def parse(string)
        JSON.parse(string).with_indifferent_access
      rescue JSON::ParserError
        parse(decode_params(string))
      end

      def encode_post_parameters(post)
        post[:parametros] = encode_params(post[:parametros].to_json)
      end

      def encode_params(params)
        Base64.strict_encode64(params)
      end

      def decode_params(params)
        Base64.decode64(params)
      end

      def success_from(response)
        response[:codResult].blank?
      end

      def message_from(response)
        return response[:parametros].to_json if success_from(response)

        response[:paramsEntradaError] || response[:idProceso]
      end

      def authorization_from(response, auth_options = {})
        return unless response[:parametros]

        [
          response[:parametros][:referencia],
          auth_options[:operation_number],
          auth_options[:amount]
        ].join('#')
      end

      def network_transaction_id_from(response)
        response.dig(:parametros, :mmppTxId)
      end

      def error_code_from(response)
        (response[:codResult] || :paramsEntradaError) unless success_from(response)
      end
    end
  end
end
