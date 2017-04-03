module ActiveMerchant
  module Billing
    class CitrusPayGateway < Gateway
      include MastercardGateway

      class_attribute :live_na_url, :live_ap_url, :test_na_url, :test_ap_url

      self.test_na_url = 'https://test-gateway.mastercard.com/api/rest/version/36/'
      self.test_ap_url = 'https://test-gateway.mastercard.com/api/rest/version/36/'

      self.live_na_url = 'https://na-gateway.mastercard.com/api/rest/version/36/'
      self.live_ap_url = 'https://ap-gateway.mastercard.com/api/rest/version/36/'

      self.display_name = 'Citrus Pay'
      self.homepage_url = 'http://www.citruspay.com/'
      self.supported_countries = %w(AR AU BR FR DE HK MX NZ SG GB US)
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :laser]
      self.ssl_version = :TLSv1

    end
  end
end

