require File.dirname(__FILE__) + '/payflow'
require File.dirname(__FILE__) + '/payflow_express_uk' 

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
      self.homepage_url = 'https://www.paypal.com/uk/webapps/mpp/pro'
      self.display_name = 'PayPal Payments Pro (UK)'
    end
  end
end

