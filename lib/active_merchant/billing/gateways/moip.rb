# third party gem
require 'moip-assinaturas'

require File.dirname(__FILE__) + '/moip/moip_core'
require File.dirname(__FILE__) + '/moip/moip_status'
require File.dirname(__FILE__) + '/moip/moip_recurring_api'

Moip::Assinaturas.config do |config|
  config.sandbox    = false
  config.token      = "FAKETOKEN"
  config.key        = "FAKEKEY"
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MoipGateway < Gateway
      include MoipStatus
      include MoipCore
      include MoipRecurringApi

      self.test_url = 'https://desenvolvedor.moip.com.br/sandbox'
      self.live_url = 'https://www.moip.com.br'

      self.supported_countries = %w(BR)
      self.supported_cardtypes = %i(visa master american_express diners_club hipercard elo hiper)
      self.supported_banks = %i(itau santander banco_do_brasil bradesco banrisul)
      self.supported_boletos = %i(bradesco)
      self.homepage_url = 'https://www.moip.com.br/'
      self.display_fullname = 'Moip Pagamentos S/A'
      self.display_name = 'Moip'
      self.display_logo = 'https://cdn.edools.com/assets/images/gateways/moip.png'
      self.default_currency = 'BRL'

      def purchase(money, payment_method, options = {})
        payment = { :payment_method => payment_method }
        pay_options = options.merge(payment)

        use_first_response = payment_method == :boleto || payment_method == :bank_transfer

        MultiResponse.run(use_first_response) do |r|
          r.process { authenticate(money, payment_method, options) }
          r.process { pay(money, r.authorization, pay_options) }
        end
      end

      def details(token)
        @query = true
        response = commit(:get, 'xml', build_url('query', token), nil, add_authentication)
        @query = false
        response
      end

      def create_plan(params)
        commit(:post, '/assinaturas/v1/plans', plan_params(params))
      end

      def update_plan(params)
        response = commit(:put, '/assinaturas/v1/plans', plan_params(params))

        if response[:success]
          find_plan(params[:plan_code])
        end
      end

      def find_plan(plan_code)
        commit(:get, "/assinaturas/v1/plans/#{plan_code}", nil)
      end

      def plan_params(params)
        unit, length = INTERVAL_MAP[params[:period]]
        moip_plan_code = params[:plan_code]

        plan_attributes = {
          code: moip_plan_code,
          name: "ONE INVOICE FOR #{length} #{unit} #{moip_plan_code}",
          description: 'PLAN USED TO CREATE SUBSCRIPTIONS BY EDOOLS',
          amount: params[:price],
          status: 'ACTIVE',
          interval: {
            unit: unit,
            length: length
          },
          trial: {
            days: params[:trials],
            enabled: params[:trials].present? && params[:trials] > 0
          }
        }

        plan_attributes[:billing_cycles] = params[:cycles] if params[:cycles]

        plan_attributes
      end

      private
      def authenticate(money, payment_method, options = {})
        commit(:post, 'xml', build_url('authenticate'), build_authenticate_request(money, options), add_authentication, payment_method)
      end

      def pay(amount, authorization, options = {})
        commit(:get, 'json', build_url('pay', build_pay_params(authorization, options)), nil, {}, nil, authorization)
      end
    end
  end
end
