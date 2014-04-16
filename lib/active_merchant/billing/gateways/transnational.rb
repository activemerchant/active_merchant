module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransnationalGateway < NetworkMerchantsGateway
      self.homepage_url = 'http://www.tnbci.com/'
      self.display_name = 'Transnational'
    end
  end
end

