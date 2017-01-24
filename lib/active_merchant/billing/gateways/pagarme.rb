require 'pagarme'
require File.dirname(__FILE__) + '/pagarme/card_pagarme.rb'
require File.dirname(__FILE__) + '/pagarme/pagarme_recurring_api.rb'
require File.dirname(__FILE__) + '/pagarme/pagarme_service.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagarmeGateway < Gateway
      include PagarmeRecurringApi
      include CardPagarme

      self.live_url = 'https://api.pagar.me/1/'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]
      self.homepage_url = 'https://pagar.me/'
      self.display_fullname = 'Pagar.me'
      self.display_name = 'Pagar.me'
      self.display_logo = 'https://cdn.edools.com/assets/images/gateways/pagarMe.png'

      STANDARD_ERROR_CODE_MAPPING = {
        'refused' => STANDARD_ERROR_CODE[:card_declined],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
      }

      def initialize(options={})
        requires!(options, :username)

        @username        = options[:username]
        @pagarme_service = PagarmeService.new(@username)
        PagarMe.api_key  = @username

        super
      end

      def details(id)
        begin
          response      = PagarMe::Transaction.find_by_id(id)
          date_limit    = response.boleto_expiration_date && (DateTime.parse(response.boleto_expiration_date) + 4.days)
          status_action = if date_limit && date_limit < Time.now
                            :cancel
                          else
                            PAYMENT_STATUS_MAP[response.status]
                          end

          Response.new(true, '', {}, payment_action: status_action, test: test?)
        rescue PagarMe::ResponseError => error
          Response.new(false, error.message, {}, test: test?)
        end
      end

      def purchase(money, payment_method, options={})
        begin
          post = {}
          add_amount(post, money)
          add_installments(post, options)
          add_soft_descriptor(post, options)
          add_payment_method(post, payment_method, options)
          add_metadata(post, options)
          add_customer(post, options)

          commit(:post, 'transactions', post)
        rescue PagarMe::ResponseError => error
          Response.new(false, error.message, {}, test: test?)
        end
      end

      def authorize(money, payment_method, options={})
        post = {}
        add_amount(post, money)
        add_installments(post, options)
        add_soft_descriptor(post, options)
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

      def create_plan(params)
        commit(:post, "plans", plan_params(params))
      end

      def find_plan(plan_code)
        plan_code = '9XQZVK' if plan_code.nil?

        commit(:get, "plans/#{plan_code}", nil)
      end

      def update_plan(params)
        plan_code = params[:plan_code]

        commit(:put, "plans/#{plan_code}", plan_params(params))
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

      def add_customer(post, options={})
        customer = options[:customer] || options['customer']
        address  = options[:address] || options['address']

        post[:customer] = customer_params(customer, address)
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_installments(post, options={})
        post[:installments] = options["credit_card"].try(:[], "installments")
      end

      def add_soft_descriptor(post, options={})
        # post[:soft_descriptor] = options["extras"].try(:[], "soft_descriptor")
      end

      def add_payment_method(post, payment_method, options)
        if payment_method == :boleto
          post[:payment_method] = payment_method
        else
          post[:payment_method] = 'credit_card'

          if options[:card_id].present?
            post[:card_id] = options[:card_id]
          elsif options["card_hash"].present?
            post[:card_hash] = options["card_hash"]
          else
            add_credit_card(post, payment_method)
          end
        end
      end

      def add_credit_card(post, credit_card)
        post[:card_id] = create_card(credit_card)
      end

      def add_metadata(post, options={})
        post[:metadata]               = {}
        post[:metadata][:order_id]    = options[:order_id]
        post[:metadata][:ip]          = options[:ip]
        post[:metadata][:merchant]    = options[:merchant]
        post[:metadata][:description] = options[:description]
        post[:metadata][:invoice]     = options[:invoice]
        post[:metadata][:email]       = options[:email]
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
          "Authorization" => "Basic " + Base64.encode64(@username.to_s + ":x").strip,
          "User-Agent" => "Pagar.me/1 ActiveMerchant/#{ActiveMerchant::VERSION}",
          "Accept-Encoding" => "deflate"
        }
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        raw_response = response = nil

        begin
          raw_response = ssl_request(method, self.live_url + endpoint,
            post_data(parameters), headers(options))

          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body

          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        response
      end

      def service_pagarme
        @pagarme_service
      end

      def commit(method, url, parameters, options = {})
        response = api_request(method, url, parameters, options)
        authorization = authorization_from(response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization,
          test: test?,
          error_code: error_code_from(response),
          plan_code: plan_code_from(response),
          external_url: boleto_url_from(response),
          payment_action: payment_action_from(response),
          subscription_action: subscription_action_from(response),
          card: card_from(response),
          gateway_transaction_code: authorization
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

      def subscription_action_from(response)
        SUBSCRIPTION_STATUS_MAP[response['status']] if response['status']
      end

      def success_from(response)
        success = ["subscription", "plan", "transaction"]
        status = ["paid", "authorized", "refunded", "waiting_payment"]

        if success.include?(response["object"])
          response["object"] == "transaction" ? status.include?(response['status']) : true
        end
      end

      def failure_from(response)
        response["status"] && response["status"] == "refused"
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

      def card_from(response)
         response["object"] == "transaction" && response["card"] || nil
      end

      def plan_code_from(response)
         response["object"] == "plan" && response["id"] || nil
      end

      def boleto_url_from(response)
         response["object"] == "transaction" && response["boleto_url"] || nil
      end

      def payment_action_from(response)
         if response["object"] == "transaction" && response["status"]
           PAYMENT_STATUS_MAP[response["status"]]
         end
      end

      def authorization_from(response)
        if success_from(response)
          response["id"]
        end
      end

      def test?
        @username.start_with?("ak_test")
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
