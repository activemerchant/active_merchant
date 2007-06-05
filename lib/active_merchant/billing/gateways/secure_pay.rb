module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayGateway < AuthorizeNetGateway
      self.live_url = self.test_url = 'https://www.securepay.com/AuthSpayAdapter/process.aspx'
      
      self.homepage_url = 'http://www.securepay.com/'
      self.display_name = 'SecurePay'
      
      private
      def split(response)
        response.split('%')
      end
    end
  end
end

