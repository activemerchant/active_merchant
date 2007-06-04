module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayGateway < AuthorizeNetGateway
      self.live_url = self.test_url = 'https://www.securepay.com/AuthSpayAdapter/process.aspx'
      
      private
      def split(response)
        response.split('%')
      end
    end
  end
end

