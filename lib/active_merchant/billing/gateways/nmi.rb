module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiGateway < AuthorizeNetGateway
      self.test_url = 'https://secure.networkmerchants.com/gateway/transact.dll'
      self.live_url = 'https://secure.networkmerchants.com/gateway/transact.dll'
      self.homepage_url = 'http://nmi.com/'
      self.display_name = 'NMI'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
    end
  end
end

