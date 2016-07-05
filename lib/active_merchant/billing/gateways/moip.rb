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
