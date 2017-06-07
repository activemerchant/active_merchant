require File.dirname(__FILE__) + '/moip/moip_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MoipGateway < Gateway
      include MoipCore

      self.test_url = 'https://desenvolvedor.moip.com.br/sandbox'
      self.live_url = 'https://www.moip.com.br'

      self.supported_countries = ['BR']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = 'https://www.moip.com.br/'
      self.display_name = 'Moip'
      self.default_currency = 'BRL'

      def purchase(money, payment_method, options = {})
        payment = { :payment_method => payment_method }
        pay_options = options.merge(payment)
        MultiResponse.run do |r|
          r.process { authenticate(money, payment_method, options) }
          r.process { pay(money, r.authorization, pay_options) }
        end
      end

      private
        def authenticate(money, payment_method, options = {})
          commit(:post, 'xml', build_url('authenticate'), build_authenticate_request(money, options), add_authentication)
        end

        def pay(amount, authorization, options = {})
          commit(:get, 'json', build_url('pay', build_pay_params(authorization, options)), nil)
        end
    end
  end
end
