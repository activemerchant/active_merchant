module ActiveMerchant
  module Billing
    class TnsGateway < Gateway
      include MastercardGateway

      class_attribute :live_na_url, :live_ap_url, :live_eu_url, :test_na_url, :test_ap_url, :test_eu_url

      VERSION = '52'

      self.live_na_url = "https://na-gateway.mastercard.com/api/rest/version/#{VERSION}/"
      self.test_na_url = "https://test-gateway.mastercard.com/api/rest/version/#{VERSION}/"

      self.live_ap_url = "https://ap-gateway.mastercard.com/api/rest/version/#{VERSION}/"
      self.test_ap_url = "https://test-gateway.mastercard.com/api/rest/version/#{VERSION}/"

      self.live_eu_url = "https://eu-gateway.mastercard.com/api/rest/version/#{VERSION}/"
      self.test_eu_url = "https://test-gateway.mastercard.com/api/rest/version/#{VERSION}/"

      self.display_name = 'Mastercard (formerly TNSPay)'
      self.homepage_url = 'https://www.mastercard.com/gateway.html'
      self.supported_countries = %w(AR AU BR FR DE HK MX NZ SG GB US)
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro]

    end
  end
end
