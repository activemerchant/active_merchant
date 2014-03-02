module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IridiumGateway < PayVectorGateway
      #Iridium lets you handle failovers on payments by providing 3 gateways in case one happens to be down
      #URLS = ['https://gw1.iridiumcorp.com/','https://gw2.iridiumcorp.com/','https://gw3.iridiumcorp.com/']      
      
      self.homepage_url = 'http://www.iridiumcorp.net/'
      self.display_name = 'Iridium'
      
      def initialize(options={})
        super
        @test_url = 'https://gw1.iridiumcorp.net/'
        @live_url = 'https://gw1.iridiumcorp.net/'
      end
      
    end
  end
end
