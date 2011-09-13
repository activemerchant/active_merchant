module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    
    #
    # Bluefin is a branded reseller of EZIC.  See the superclass for more details.
    #
    class BluefinGateway < EzicGateway
      TEST_URL = 'https://secure.bluefingateway.com:1402/gw/sas/direct3.1'
      LIVE_URL = 'https://secure.bluefingateway.com:1402/gw/sas/direct3.1'
      
      # There is no testing gateway, the account has to be in test mode or run this specific CC number
      TESTING_CC = '4444333322221111'
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.bluefin.com/'
      
      # The name of the gateway
      self.display_name = 'Bluefin Gateway (EZIC)'      
    end
  end
end

