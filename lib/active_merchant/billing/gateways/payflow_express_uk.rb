module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressUkGateway < PayflowExpressGateway
      self.default_currency = 'GBP'
      self.partner = 'PayPalUk'
    end
  end
end

