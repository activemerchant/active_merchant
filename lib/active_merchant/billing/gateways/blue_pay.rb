module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BluePayGateway < AuthorizeNetGateway
      self.test_url = "https://secure.bluepay.com/interfaces/a.net.test"
      self.live_url = "https://secure.bluepay.com/interfaces/a.net"
      self.homepage_url = 'http://www.bluepay.com/'
      self.display_name = 'BluePay'
    end
  end
end

