module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowUkGateway < PayflowGateway
      self.default_currency = 'GBP'
      self.partner = 'PayPalUk'
      
      def express
        @express ||= PayflowExpressUkGateway.new(@options)
      end
      
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :solo, :switch]
      self.supported_countries = ['GB']
    end
  end
end

