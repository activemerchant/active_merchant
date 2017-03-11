require_relative 'genesis_gateway'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EcomprocessingDirectGateway < GenesisGateway

      self.test_url     = 'https://staging-shopify.e-comprocessing.com/payments/api/v1/process'
      self.live_url     = 'https://shopify.e-comprocessing.com/payments/api/v1/process'

      self.homepage_url = 'https://www.e-comprocessing.com/'
      self.display_name = 'E-ComProcessing Direct'

    end
  end
end
