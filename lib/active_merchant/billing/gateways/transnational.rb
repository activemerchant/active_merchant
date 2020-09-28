module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransnationalGateway < NetworkMerchantsGateway
      self.homepage_url = 'http://www.tnbci.com/'
      self.display_name = 'Transnational'
      self.supported_countries = ["US"]
    end
  end
end

