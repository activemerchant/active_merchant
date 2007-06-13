module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayGateway < AuthorizeNetGateway
      self.live_url = self.test_url = 'https://www.securepay.com/AuthSpayAdapter/process.aspx'
      
      self.homepage_url = 'http://www.securepay.com/'
      self.display_name = 'SecurePay'
      
      # Limit support to purchase() for the time being
      undef_method :authorize, :capture, :void, :credit
      
      def test?
        Base.gateway_mode == :test
      end
      
      private
      def split(response)
        response.split('%')
      end
    end
  end
end

