module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BarclaysEpdqExtraPlusGateway < OgoneGateway
      self.test_url = "https://mdepayments.epdq.co.uk/ncol/test/"
      self.live_url = "https://payments.epdq.co.uk/ncol/prod/"

      self.display_name = "Barclays ePDQ Extra Plus"
      self.homepage_url = "http://www.barclaycard.co.uk/business/accepting-payments/epdq-ecomm/"

      self.supported_countries = ["GB"]
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro]
      self.default_currency = "GBP"
    end
  end
end
