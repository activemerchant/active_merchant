require_relative 'genesis_gateway'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EmerchantpayDirectGateway < GenesisGateway

      self.test_url     = 'https://staging-shopify.emerchantpay.com/payments/api/v1/process'
      self.live_url     = 'https://shopify.emerchantpay.com/payments/api/v1/process'

      self.homepage_url = 'https://www.emerchantpay.com/'
      self.display_name = 'eMerchantPay Direct'

    end
  end
end
