module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressUkGateway < PayflowExpressGateway
      self.default_currency = 'GBP'
      self.partner = 'PayPalUk'
      
      self.supported_countries = ['GB']
    end
  end
end

