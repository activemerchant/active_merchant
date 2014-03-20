require File.dirname(__FILE__) + '/cc5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AkbankGateway < CC5Gateway
      self.live_url = self.test_url = 'https://testsanalpos.est.com.tr/servlet/cc5ApiServer'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'TR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      # The homepage URL of the gateway
      self.homepage_url = 'https://www.sanalakpos.com/'

      # The name of the gateway
      self.display_name = 'Akbank WebPOS'
    end
  end
end