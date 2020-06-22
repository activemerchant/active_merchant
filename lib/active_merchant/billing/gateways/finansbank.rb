require 'active_merchant/billing/gateways/cc5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FinansbankGateway < CC5Gateway
      self.live_url = 'https://www.fbwebpos.com/servlet/cc5ApiServer'
      self.test_url = 'https://entegrasyon.asseco-see.com.tr/fim/api'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w[US TR]

      # The card types supported by the payment gateway
      self.supported_cardtypes = %i[visa master]

      # The homepage URL of the gateway
      self.homepage_url = 'https://www.fbwebpos.com/'

      # The name of the gateway
      self.display_name = 'Finansbank WebPOS'
    end
  end
end
