module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayboxDirectPlusGateway < PayboxDirectGateway
      # Payment API Version
      self.api_version = '00104'

      # The name of the gateway
      self.display_name = 'Paybox Direct Plus'
    end
  end
end
