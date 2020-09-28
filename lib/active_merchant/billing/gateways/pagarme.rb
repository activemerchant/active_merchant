module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagarmeGateway < Gateway
      self.live_url = 'https://api.pagar.me/1/'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]

      self.homepage_url = 'https://pagar.me/'
      self.display_name = 'Pagar.me'

      STANDARD_ERROR_CODE_MAPPING = {
        'refused' => STANDARD_ERROR_CODE[:card_declined],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
      }

      def initialize(options={})
        requires!(options, :api_key)
        @api_key = options[:api_key]

        super
      end

      def purchase(money, payment_method, options={})
        post = {}
        add_amount(post, money)
        add_payment_method(post, payment_method)
        add_metadata(post, options)

        commit(:post, 'transactions', post)
      end

      def authorize(money, payment_method, options={})
        post = {}
        add_amount(post, money)
        add_payment_method(post, payment_method)
        add_metadata(post, options)

        post[:capture] = false

        commit(:post, 'transactions', post)
      end

      def capture(money, authorization, options={})
        if authorization.nil?
          return Response.new(false, 'Não é possível capturar uma transação sem uma prévia autorização.')
        end

        post = {}
        commit(:post, "transactions/#{authorization}/capture", post)
      end

      def refund(money, authorization, options={})
        if authorization.nil?
          return Response.new(false, 'Não é possível estornar uma transação sem uma prévia captura.')
        end

        void(authorization, options)
      end

      def void(authorization, options={})
        if authorization.nil?
          return Response.new(false, 'Não é possível estornar uma transação autorizada sem uma prévia autorização.')
        end

        post = {}
        commit(:post, "transactions/#{authorization}/refund", post)
      end

      def verify(payment_method, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(127, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card_number=)\d+), '\1[FILTERED]').
          gsub(%r((card_cvv=)\d+), '\1[FILTERED]')
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_payment_method(post, payment_method)
        post[:payment_method] = 'credit_card'
        add_credit_card(post, payment_method)
      end

      def add_credit_card(post, credit_card)
        post[:card_number] = credit_card.number
        post[:card_holder_name] = credit_card.name
        post[:card_expiration_date] = "#{credit_card.month}/#{credit_card.year}"
        post[:card_cvv] = credit_card.verification_value
      end

      def add_metadata(post, options={})
        post[:metadata] = {}
        post[:metadata][:order_id] = options[:order_id]
        post[:metadata][:ip] = options[:ip]
        post[:metadata][:customer] = options[:customer]
        post[:metadata][:invoice] = options[:invoice]
        post[:metadata][:merchant] = options[:merchant]
        post[:metadata][:description] = options[:description]
        post[:metadata][:email] = options[:email]
      end

      def parse(body)
        JSON.parse(body)
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value != false && value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join("&")
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def headers(options = {})
        {
          "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":x").strip,
          "User-Agent" => "Pagar.me/1 ActiveMerchant/#{ActiveMerchant::VERSION}",
          "Accept-Encoding" => "deflate"
        }
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, self.live_url + endpoint, post_data(parameters), headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(method, url, parameters, options = {})
        response = api_request(method, url, parameters, options)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
		  msg = 'Resposta inválida retornada pela API do Pagar.me. Por favor entre em contato com suporte@pagar.me se você continuar recebendo essa mensagem.'
        msg += "  (A resposta retornada pela API foi #{raw_response.inspect})"
        {
          "errors" => [{
            "message" => msg
          }]
        }
      end

      def success_from(response)
        success_purchase = response.key?("status") && response["status"] == "paid"
        success_authorize = response.key?("status") && response["status"] == "authorized"
        success_refund = response.key?("status") && response["status"] == "refunded"

        success_purchase || success_authorize || success_refund
      end

      def failure_from(response)
        response.key?("status") && response["status"] == "refused"
      end

      def message_from(response)
        if success_from(response)
          case response["status"]
          when "paid"
            "Transação aprovada"
          when "authorized"
            "Transação autorizada"
          when "refunded"
            "Transação estornada"
          else
            "Transação com status '#{response["status"]}'"
          end
        elsif failure_from(response)
          "Transação recusada"
        elsif response.key?("errors")
          response["errors"][0]["message"]
        else
          msg = json_error(response)
          msg["errors"][0]["message"]
        end
      end

      def authorization_from(response)
        if success_from(response)
          response["id"]
        end
      end

      def test?()
        @api_key.start_with?("ak_test")
      end

      def error_code_from(response)
        if failure_from(response)
          STANDARD_ERROR_CODE_MAPPING["refused"]
        elsif response.key?("errors")
          STANDARD_ERROR_CODE_MAPPING["processing_error"]
        end
      end
    end
  end
end
