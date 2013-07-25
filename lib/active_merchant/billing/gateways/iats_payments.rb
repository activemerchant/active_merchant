require File.dirname(__FILE__) + '/authorize_net'


module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayGateway < AuthorizeNetGateway
      self.live_url = self.test_url = 'https://www.iatspayments.com/netgate/AEGateway.aspx'


      self.homepage_url = 'http://www.iatspayments.com/'
      self.display_name = 'IATSPayments'


      # Limit support to purchase() for the time being
      # JRuby chokes here
      # undef_method :authorize, :capture, :void, :credit


      undef_method :authorize
      undef_method :capture
      undef_method :void
      undef_method :credit


      private


      def split(response)
        response.split(',')
      end
    end
  end
end
