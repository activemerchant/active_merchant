module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AllpointspaymentsGateway < IridiumGateway
      self.money_format = :cents
      self.default_currency = 'EUR'
      self.supported_cardtypes = [ :visa, :switch, :maestro, :master, :solo, :american_express, :jcb ]
      self.supported_countries = [ 'IE', 'GB' ]
      self.homepage_url = 'http://www.allpointspayments.com/'
      self.display_name = 'AllPointsPayments'
      
      def initialize(options={})
        super
        @test_url = 'https://gw1.allpointspayments.net:4430/'
        @live_url = 'https://gw1.allpointspayments.net:4430/'
      end
      
    end
  end
end