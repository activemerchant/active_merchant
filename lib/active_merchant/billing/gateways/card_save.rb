module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardSaveGateway < IridiumGateway
      #CardSave lets you handle failovers on payments by providing 3 gateways in case one happens to be down
      #URLS = ['https://gw1.cardsaveonlinepayments.com:4430/','https://gw2.cardsaveonlinepayments.com:4430/','https://gw3.cardsaveonlinepayments.com:4430/']
      class << self
        attr_accessor :test_url
        attr_accessor :live_url
        def test_url
          @test_url ||= 'https://gw1.cardsaveonlinepayments.com:4430/'
        end
        def live_url
          @live_url ||= 'https://gw1.cardsaveonlinepayments.com:4430/'
        end
      end
      
      self.money_format = :cents
      self.default_currency = 'GBP'
      self.supported_cardtypes = [ :visa, :switch, :maestro, :master, :solo, :american_express, :jcb ]
      self.supported_countries = [ 'GB' ]
      self.homepage_url = 'http://www.cardsave.net/'
      self.display_name = 'CardSave'
      
    end
  end
end

