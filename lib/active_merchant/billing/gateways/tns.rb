module ActiveMerchant
  module Billing
    class TnsGateway < Gateway
      include MastercardGateway

      class_attribute :live_na_url, :live_ap_url, :test_na_url, :test_ap_url

      self.live_na_url = 'https://secure.na.tnspayments.com/api/rest/version/36/'
      self.test_na_url = 'https://secure.na.tnspayments.com/api/rest/version/36/'

      self.live_ap_url = 'https://secure.ap.tnspayments.com/api/rest/version/36/'
      self.test_ap_url = 'https://secure.ap.tnspayments.com/api/rest/version/36/'

      self.display_name = 'TNS'
      self.homepage_url = 'http://www.tnsi.com/'
      self.supported_countries = %w(AR AU BR FR DE HK MX NZ SG GB US)
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :laser]
      self.ssl_version = :TLSv1

    end
  end
end
