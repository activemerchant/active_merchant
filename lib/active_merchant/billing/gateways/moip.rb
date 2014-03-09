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

      def authorize(money, payment_method, options = {})
        commit(:post, 'xml', build_url('authorize'), build_authorize_request(money, payment_method, options), add_authentication)
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process{authorize(money, payment_method, options)}
          r.process{capture(r.authorization, payment_method, options)}
        end
      end

      def capture(authorization, payment_method, options = {})
        commit(:get, 'json', build_url('capture', build_capture_params(authorization, payment_method, options)), nil)
      end
    end
  end
end